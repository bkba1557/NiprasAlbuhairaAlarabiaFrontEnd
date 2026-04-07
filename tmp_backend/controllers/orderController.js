const Order = require('../models/Order');
const Customer = require('../models/Customer');
const Supplier = require('../models/Supplier');
const Driver = require('../models/Driver');
const Station = require('../models/Station');
const FuelStation = require('../models/FuelStation');
const User = require('../models/User');
const { sendEmail } = require('../services/emailService');
const EmailTemplates = require('../services/emailTemplates');
const getOrderEmails = require('../utils/getOrderEmails');
const Activity = require('../models/Activity');
const Notification = require('../models/Notification');
const ownerOrderNotificationService = require('../services/ownerOrderNotificationService');
const NotificationService = require('../services/notificationService');
const WhatsAppService = require('../services/whatsappService');
const {
  extractOrderDraftFromDocument,
  extractTextFromPdfBuffer,
} = require('../services/orderDocumentAutofillService');
const {
  buildAssignedOrdersFilter,
  findDriverRecipients,
  userCanAccessOrder,
  userRequiresAssignedOrdersOnly,
  resolveLinkedDriverId,
} = require('../utils/driverAccess');

const mongoose = require('mongoose');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|gif|pdf|doc|docx|zip/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('نوع الملف غير مدعوم'));
    }
  }
}).fields([
  { name: 'attachments', maxCount: 5 },
  { name: 'supplierDocuments', maxCount: 5 },
  { name: 'customerDocuments', maxCount: 5 }
]);

exports.uploadMiddleware = upload;

const ARAMCO_DISTRIBUTION_LOCATIONS = Object.freeze({
  الرياض: ['أرامكو الشمال', 'أرامكو الشرق'],
  القصيم: ['أرامكو بريدة'],
  الجوف: ['أرامكو الجوف'],
  'المدينة المنورة': ['أرامكو المدينة'],
  جدة: ['أرامكو جدة'],
  'المنطقة الشرقية': ['أرامكو الدمام'],
});

const autofillUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const extension = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = new Set(['.pdf', '.jpg', '.jpeg', '.png']);
    if (allowedExtensions.has(extension)) {
      return cb(null, true);
    }
    return cb(new Error('الملف المسموح به للتعبئة يجب أن يكون PDF أو صورة'));
  },
}).single('document');

const importDocumentsUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const extension = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = new Set(['.pdf', '.jpg', '.jpeg', '.png']);
    if (allowedExtensions.has(extension)) {
      return cb(null, true);
    }
    return cb(new Error('ملفات الاستيراد يجب أن تكون PDF أو صورة'));
  },
}).array('documents', 20);

function simplifyAramcoCity(value) {
  const cleaned = normalizeImportValue(value);
  if (!cleaned) return null;
  const simplified = cleaned.replace(/^ارامكو\s+/, '').trim();
  return simplified || cleaned;
}

function normalizeImportValue(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[\u064b-\u065f\u0670]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/[ؤئ]/g, 'و')
    .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function matchAramcoDistributionLocation(rawValue) {
  const normalizedValue = normalizeImportValue(rawValue);
  if (!normalizedValue) return null;

  for (const [area, stations] of Object.entries(ARAMCO_DISTRIBUTION_LOCATIONS)) {
    for (const station of stations) {
      const normalizedStation = normalizeImportValue(station);
      const simplifiedStation = normalizedStation.replace(/^ارامكو\s+/, '').trim();
      if (
        normalizedValue === normalizedStation ||
        normalizedValue === simplifiedStation ||
        normalizedStation.includes(normalizedValue) ||
        normalizedValue.includes(normalizedStation) ||
        (simplifiedStation && normalizedValue.includes(simplifiedStation))
      ) {
        const city = simplifyAramcoCity(station) || station;
        return {
          area,
          city,
          address: station,
        };
      }
    }
  }

  return null;
}

function expandStationCodes(codes = []) {
  const expanded = new Set();
  if (!Array.isArray(codes)) return [];

  for (const raw of codes) {
    const code = String(raw || '').trim().toUpperCase();
    if (!code) continue;
    expanded.add(code);

    const sMatch = code.match(/^S(\d{3,4})$/);
    if (sMatch) {
      expanded.add(`STN${sMatch[1]}`);
    }
    const stnMatch = code.match(/^STN(\d{3,4})$/);
    if (stnMatch) {
      expanded.add(`S${stnMatch[1]}`);
    }

    const hyphenMatch = code.match(/^([A-Z])-(\d{2,4})$/);
    if (hyphenMatch) {
      expanded.add(`${hyphenMatch[1]}${hyphenMatch[2]}`);
    }
    const compactMatch = code.match(/^([A-Z])(\d{2,4})$/);
    if (compactMatch) {
      expanded.add(`${compactMatch[1]}-${compactMatch[2]}`);
    }
  }

  return Array.from(expanded);
}

async function lookupDistributionLocation({ stationCodes = [], candidates = [] }) {
  const expandedCodes = expandStationCodes(stationCodes);
  if (expandedCodes.length > 0) {
    const station = await Station.findOne({
      stationCode: { $in: expandedCodes },
    })
      .select('stationCode stationName city location')
      .lean();

    if (station) {
      return (
        matchAramcoDistributionLocation(station.stationName) ||
        matchAramcoDistributionLocation(station.city) || {
          city: station.city || station.stationName,
          area: null,
          address: station.location || station.city || station.stationName,
        }
      );
    }

    const fuelStation = await FuelStation.findOne({
      stationCode: { $in: expandedCodes },
    })
      .select('stationCode stationName city region address')
      .lean();

    if (fuelStation) {
      return (
        matchAramcoDistributionLocation(fuelStation.stationName) ||
        matchAramcoDistributionLocation(fuelStation.city) || {
          city: fuelStation.stationName || fuelStation.city,
          area: fuelStation.region || null,
          address:
            fuelStation.address ||
            fuelStation.stationName ||
            fuelStation.city ||
            null,
        }
      );
    }
  }

  for (const candidate of candidates) {
    const matchedLocation = matchAramcoDistributionLocation(candidate);
    if (matchedLocation) {
      return matchedLocation;
    }
  }

  for (const candidate of candidates) {
    const normalizedCandidate = String(candidate || '').trim();
    if (!normalizedCandidate) continue;
    const regex = new RegExp(escapeRegex(normalizedCandidate), 'i');

    const station = await Station.findOne({
      $or: [{ stationName: regex }, { city: regex }, { location: regex }],
    })
      .select('stationName city location')
      .lean();

    if (station) {
      return (
        matchAramcoDistributionLocation(station.stationName) ||
        matchAramcoDistributionLocation(station.city) || {
          city: station.city || station.stationName,
          area: null,
          address: station.location || station.city || station.stationName,
        }
      );
    }

    const fuelStation = await FuelStation.findOne({
      $or: [{ stationName: regex }, { city: regex }, { address: regex }],
    })
      .select('stationName city region address')
      .lean();

    if (fuelStation) {
      return (
        matchAramcoDistributionLocation(fuelStation.stationName) ||
        matchAramcoDistributionLocation(fuelStation.city) || {
          city: fuelStation.stationName || fuelStation.city,
          area: fuelStation.region || null,
          address:
            fuelStation.address ||
            fuelStation.stationName ||
            fuelStation.city ||
            null,
        }
      );
    }
  }

  return null;
}

async function resolveImportedLocation({ draft, meta, supplier }) {
  const candidateValues = [
    draft?.city,
    draft?.region,
    meta?.rawLocation,
    supplier?.city,
    supplier?.address,
  ].filter(Boolean);

  const directMatch = candidateValues
    .map((value) => matchAramcoDistributionLocation(value))
    .find(Boolean);
  if (directMatch) {
    return directMatch;
  }

  const stationCodes = Array.isArray(meta?.stationCodes)
    ? meta.stationCodes
    : [];
  const lookedUpLocation = await lookupDistributionLocation({
    stationCodes,
    candidates: candidateValues,
  });
  if (lookedUpLocation) {
    return lookedUpLocation;
  }

  if (draft?.city || draft?.region) {
    const city = draft.city || supplier?.city || null;
    const area = draft.region || null;
    return {
      city,
      area,
      address: city || area ? [city, area].filter(Boolean).join(' - ') : null,
    };
  }

  if (supplier?.city) {
    return {
      city: supplier.city,
      area: null,
      address: supplier.address || supplier.city,
    };
  }

  return null;
}

async function resolveOrCreateImportedSupplier({
  supplierName,
  location,
  user,
  cache,
}) {
  const normalizedName = normalizeImportValue(supplierName);
  if (!normalizedName) {
    throw new Error('تعذر تحديد اسم المورد من الملف');
  }

  if (cache?.has(normalizedName)) {
    return { supplier: cache.get(normalizedName), created: false };
  }

  const existingSupplier = await Supplier.findOne({
    name: new RegExp(`^${escapeRegex(supplierName)}$`, 'i'),
  });
  if (existingSupplier) {
    cache?.set(normalizedName, existingSupplier);
    return { supplier: existingSupplier, created: false };
  }

  const supplier = await Supplier.create({
    name: supplierName,
    company: supplierName,
    contactPerson: supplierName,
    phone: '0000000000',
    supplierType: 'وقود',
    rating: 3,
    isActive: true,
    city: location?.city || undefined,
    address: location?.address || undefined,
    notes: 'تم إنشاؤه تلقائيًا من استيراد ملف طلب مورد',
    createdBy: user._id,
  });

  cache?.set(normalizedName, supplier);
  return { supplier, created: true };
}

function shiftTime(time, minutesToAdd) {
  const match = String(time || '').match(/^(\d{2}):(\d{2})$/);
  if (!match) return '10:00';

  const base = new Date(2000, 0, 1, Number(match[1]), Number(match[2]));
  base.setMinutes(base.getMinutes() + minutesToAdd);

  return `${String(base.getHours()).padStart(2, '0')}:${String(base.getMinutes()).padStart(2, '0')}`;
}

function toDateValue(value, fallback) {
  if (!value) return fallback;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? fallback : date;
}

function buildImportedOrderData({
  draft,
  supplier,
  location,
  user,
  fileName,
}) {
  const now = new Date();
  const orderDate = toDateValue(
    draft.orderDate || draft.loadingDate,
    now
  );
  const loadingDate = toDateValue(
    draft.loadingDate || draft.orderDate,
    orderDate
  );
  const loadingTime = draft.loadingTime || '08:00';
  const arrivalDate = toDateValue(draft.arrivalDate, loadingDate);
  const arrivalTime = draft.arrivalTime || shiftTime(loadingTime, 90);
  const address =
    location?.address ||
    [location?.city, location?.area].filter(Boolean).join(' - ');

  const noteParts = [
    draft.notes,
    fileName ? `تم الاستيراد من الملف: ${fileName}` : null,
  ].filter(Boolean);

  return {
    supplier: supplier._id,
    supplierName: supplier.name,
    supplierCompany: supplier.company,
    supplierContactPerson: supplier.contactPerson,
    supplierPhone: supplier.phone,
    supplierAddress: supplier.address || address,
    supplierOrderNumber: draft.supplierOrderNumber || undefined,
    orderSource: 'مورد',
    orderDate,
    loadingDate,
    loadingTime,
    arrivalDate,
    arrivalTime,
    city: location?.city || supplier.city || 'غير محدد',
    area: location?.area || 'غير محدد',
    address: address || supplier.address || 'غير محدد',
    fuelType: draft.fuelType || undefined,
    quantity: draft.quantity || undefined,
    unit: 'لتر',
    notes: noteParts.join(' - ') || undefined,
    createdBy: user._id,
    createdByName: user.name,
  };
}

exports.autofillOrderFromDocument = async (req, res) => {
  try {
    autofillUpload(req, res, async (err) => {
      if (err) {
        return res.status(400).json({ error: err.message });
      }

      const extractedText =
        typeof req.body?.extractedText === 'string'
          ? req.body.extractedText.trim()
          : '';

      if (!req.file && !extractedText) {
        return res.status(400).json({
          error: 'ارفع ملف PDF أو صورة أو أرسل النص المستخرج من الملف',
        });
      }

      try {
        const result = await extractOrderDraftFromDocument({
          extractedText,
          file: req.file,
        });

        try {
          const stationCodes = Array.isArray(result?.meta?.stationCodes)
            ? result.meta.stationCodes
            : [];
          const candidates = [
            result?.draft?.city,
            result?.draft?.region,
            result?.meta?.rawLocation,
          ].filter(Boolean);

          const location = await lookupDistributionLocation({
            stationCodes,
            candidates,
          });

          if (location && result?.draft) {
            if (!result.draft.city && location.city) {
              result.draft.city = location.city;
            }
            if (!result.draft.region && location.area) {
              result.draft.region = location.area;
            }
            result.suggestedLocation = location;
          }
        } catch (_) {
          // Ignore lookup failures.
        }

        return res.status(200).json({
          success: true,
          data: result,
        });
      } catch (parseError) {
        return res.status(422).json({
          error: parseError.message || 'تعذر استخراج بيانات الطلب من الملف',
        });
      }
    });
  } catch (error) {
    console.error('❌ Error autofilling order from document:', error);
    return res.status(500).json({
      error: 'حدث خطأ أثناء معالجة الملف',
    });
  }
};

exports.importSupplierOrdersFromDocuments = async (req, res) => {
  try {
    importDocumentsUpload(req, res, async (err) => {
      if (err) {
        return res.status(400).json({ error: err.message });
      }

      const files = Array.isArray(req.files) ? req.files : [];
      if (files.length === 0) {
        return res.status(400).json({
          error: 'ارفع ملفًا واحدًا على الأقل لاستيراد طلبات المورد',
        });
      }

      const supplierCache = new Map();
      const results = [];

      for (const file of files) {
        try {
          const extractedText = file.mimetype?.includes('pdf')
            ? extractTextFromPdfBuffer(file)
            : '';
          const extraction = await extractOrderDraftFromDocument({
            extractedText,
            file,
          });

          const supplierName =
            extraction.draft?.supplierName ||
            extraction.meta?.supplierNameFromFile;
          const initialLocation = await resolveImportedLocation({
            draft: extraction.draft,
            meta: extraction.meta,
          });

          const { supplier, created } = await resolveOrCreateImportedSupplier({
            supplierName,
            location: initialLocation,
            user: req.user,
            cache: supplierCache,
          });

          const finalLocation = await resolveImportedLocation({
            draft: extraction.draft,
            meta: extraction.meta,
            supplier,
          });

          let existingOrder = null;
          if (extraction.draft?.supplierOrderNumber) {
            existingOrder = await Order.findOne({
              supplier: supplier._id,
              supplierOrderNumber: extraction.draft.supplierOrderNumber,
            }).select('_id orderNumber');
          }

          if (existingOrder) {
            results.push({
              fileName: file.originalname,
              status: 'skipped',
              reason: 'رقم طلب المورد موجود مسبقًا لهذا المورد',
              supplierName: supplier.name,
              supplierOrderNumber: extraction.draft.supplierOrderNumber,
              existingOrderId: existingOrder._id,
              existingOrderNumber: existingOrder.orderNumber,
            });
            continue;
          }

          const orderData = buildImportedOrderData({
            draft: extraction.draft,
            supplier,
            location: finalLocation,
            user: req.user,
            fileName: file.originalname,
          });

          const order = new Order(orderData);
          await order.save();

          results.push({
            fileName: file.originalname,
            status: 'created',
            orderId: order._id,
            orderNumber: order.orderNumber,
            supplierName: supplier.name,
            supplierOrderNumber: order.supplierOrderNumber || null,
            supplierCreated: created,
            warnings: extraction.warnings || [],
          });
        } catch (fileError) {
          results.push({
            fileName: file.originalname,
            status: 'failed',
            reason: fileError.message || 'فشل في معالجة الملف',
          });
        }
      }

      const createdCount = results.filter((item) => item.status === 'created').length;
      const skippedCount = results.filter((item) => item.status === 'skipped').length;
      const failedCount = results.filter((item) => item.status === 'failed').length;

      return res.status(200).json({
        success: true,
        data: {
          createdCount,
          skippedCount,
          failedCount,
          results,
        },
      });
    });
  } catch (error) {
    console.error('❌ Error importing supplier orders from documents:', error);
    return res.status(500).json({
      error: 'حدث خطأ أثناء استيراد ملفات طلبات المورد',
    });
  }
};

function extractFilenameFromUrl(value, fallback = 'attachment') {
  try {
    const pathname = new URL(value).pathname;
    const decoded = decodeURIComponent(pathname.split('/').pop() || '').trim();
    return decoded || fallback;
  } catch (_) {
    return fallback;
  }
}

function toRemoteAttachment(item, user, prefix = 'attachment', index = 0) {
  if (!item || typeof item !== 'object') return null;
  const rawPath = typeof item.path === 'string' ? item.path.trim() : '';
  if (!rawPath) return null;
  const rawName = typeof item.filename === 'string' ? item.filename.trim() : '';
  return {
    filename: rawName || extractFilenameFromUrl(rawPath, `${prefix}-${index + 1}`),
    path: rawPath,
    uploadedAt: new Date(),
    uploadedBy: user?._id,
  };
}

function parseRemoteAttachments(value, user, prefix = 'attachment') {
  if (!value) return [];
  let parsed = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch (_) {
      return [];
    }
  }
  if (!Array.isArray(parsed)) return [];
  return parsed
    .map((item, index) => toRemoteAttachment(item, user, prefix, index))
    .filter(Boolean);
}

function isRemoteFilePath(value) {
  return typeof value === 'string' && /^https?:\/\//i.test(value.trim());
}


function formatDuration(milliseconds) {
  const totalSeconds = Math.floor(milliseconds / 1000);
  const days = Math.floor(totalSeconds / (3600 * 24));
  const hours = Math.floor((totalSeconds % (3600 * 24)) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  
  const parts = [];
  if (days > 0) parts.push(`${days} يوم`);
  if (hours > 0) parts.push(`${hours} ساعة`);
  if (minutes > 0) parts.push(`${minutes} دقيقة`);
  
  return parts.join(' و ') || 'أقل من دقيقة';
}



const INACTIVITY_ALERT_INTERVAL_MS = 7 * 24 * 60 * 60 * 1000;

function toIdString(value) {
  if (!value) return null;
  if (typeof value === 'object' && value._id) {
    return value._id.toString();
  }
  const normalized = String(value).trim();
  return normalized || null;
}

async function sendDriverAssignmentNotification({ order, actor }) {
  const driverId = toIdString(order?.driver?._id || order?.driver || order?.driverId);
  if (!driverId) return;

  const recipients = await findDriverRecipients(driverId);
  if (!recipients.length) return;

  const locationText = [order?.city, order?.area, order?.address]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join(' - ');

  const partyName = String(order?.customerName || order?.supplierName || '').trim();
  const messageParts = [
    `تم تعيين الطلب ${order?.orderNumber || ''} لك`.trim(),
    partyName ? `الجهة: ${partyName}` : '',
    locationText ? `الموقع: ${locationText}` : '',
  ].filter(Boolean);

  await NotificationService.send({
    type: 'order_assigned',
    title: 'تم تعيين طلب جديد لك',
    message: messageParts.join(' • '),
    data: {
      orderId: String(order?._id || ''),
      orderNumber: order?.orderNumber || '',
      status: order?.status || '',
      customerName: order?.customerName || '',
      supplierName: order?.supplierName || '',
      city: order?.city || '',
      area: order?.area || '',
      address: order?.address || '',
      loadingDate: order?.loadingDate || null,
      loadingTime: order?.loadingTime || '',
      arrivalDate: order?.arrivalDate || null,
      arrivalTime: order?.arrivalTime || '',
      driverId,
    },
    recipients,
    priority: 'high',
    createdBy: actor?._id,
    orderId: order?._id,
    channels: ['in_app', 'push', 'email'],
  });
}

async function sendOwnerDriverLoadingNotification({ order, actor }) {
  const users = await User.find({
    role: { $in: ['movement', 'owner', 'admin'] },
    isBlocked: { $ne: true },
  }).select('_id').lean();

  const recipients = [...new Set(users.map((user) => String(user._id || '')).filter(Boolean))];
  if (!recipients.length) {
    return;
  }

  const driverName = String(order?.driverName || order?.driver?.name || '').trim() || 'السائق';
  const fuelType = String(order?.actualFuelType || '').trim();
  const litersValue = Number(order?.actualLoadedLiters);
  const litersText = Number.isFinite(litersValue) && litersValue > 0
    ? `${litersValue} لتر`
    : 'غير محدد';
  const stationName = String(order?.loadingStationName || order?.supplierName || 'محطة أرامكو').trim();
  const title = `تم إرسال بيانات التعبئة للطلب ${order?.orderNumber || ''}`.trim();
  const message = [
    `أرسل ${driverName} بيانات التعبئة للطلب ${order?.orderNumber || ''}`.trim(),
    fuelType ? `الوقود: ${fuelType}` : '',
    litersText ? `الكمية الفعلية: ${litersText}` : '',
    stationName ? `المحطة: ${stationName}` : '',
    order?.customerName ? `العميل: ${order.customerName}` : '',
  ].filter(Boolean).join(' • ');

  await NotificationService.send({
    type: 'status_changed',
    title,
    message,
    data: {
      event: 'driver_loading_submitted',
      orderId: String(order?._id || ''),
      orderNumber: order?.orderNumber || '',
      status: order?.status || '',
      driverId: String(order?.driver?._id || order?.driver || ''),
      driverName,
      customerName: order?.customerName || '',
      supplierName: order?.supplierName || '',
      loadingStationName: stationName,
      actualFuelType: fuelType,
      actualLoadedLiters: Number.isFinite(litersValue) ? litersValue : null,
      driverLoadingSubmittedAt: order?.driverLoadingSubmittedAt || null,
    },
    recipients,
    priority: 'high',
    createdBy: actor?._id,
    orderId: order?._id,
    channels: ['in_app', 'push', 'email'],
  });
}

const SUPPLIER_PORTAL_CARRIER = 'شركة البحيرة العربية';
const SUPPLIER_PORTAL_REVIEW_ROLES = ['movement', 'owner', 'admin', 'manager'];

const isSupplierPortalUser = (user) =>
  String(user?.role || '').trim().toLowerCase() === 'supplier';

const isSupplierPortalReviewUser = (user) =>
  SUPPLIER_PORTAL_REVIEW_ROLES.includes(String(user?.role || '').trim().toLowerCase());

const normalizePortalStatus = (value) => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'approved') return 'approved';
  if (normalized === 'rejected') return 'rejected';
  return 'pending_review';
};

async function ensureSupplierPortalOrderAccess(user, order) {
  if (!order) return false;
  if (!isSupplierPortalUser(user)) return true;
  const userSupplierId = toIdString(user?.supplierId);
  const orderSupplierId = toIdString(order?.supplier?._id || order?.supplier);
  return Boolean(userSupplierId && orderSupplierId && userSupplierId === orderSupplierId);
}

async function findSupplierPortalRecipientIds({
  supplierId,
  includeSupplierUsers = false,
  includeReviewRoles = false,
  excludeUserId,
}) {
  const orConditions = [];
  if (includeSupplierUsers && supplierId) {
    orConditions.push({
      role: 'supplier',
      supplierId,
      isBlocked: { $ne: true },
    });
  }
  if (includeReviewRoles) {
    orConditions.push({
      role: { $in: SUPPLIER_PORTAL_REVIEW_ROLES },
      isBlocked: { $ne: true },
    });
  }

  if (!orConditions.length) return [];

  const users = await User.find({ $or: orConditions }).select('_id').lean();
  const recipients = [
    ...new Set(users.map((user) => toIdString(user._id)).filter(Boolean)),
  ];
  const excluded = toIdString(excludeUserId);
  return excluded ? recipients.filter((id) => id !== excluded) : recipients;
}

async function notifySupplierPortal({
  order,
  actor,
  title,
  message,
  type = 'status_changed',
  includeSupplierUsers = false,
  includeReviewRoles = false,
  extraData = {},
}) {
  const supplierId = toIdString(order?.supplier?._id || order?.supplier);
  const recipients = await findSupplierPortalRecipientIds({
    supplierId,
    includeSupplierUsers,
    includeReviewRoles,
    excludeUserId: actor?._id,
  });

  if (!recipients.length) {
    return;
  }

  await NotificationService.send({
    type,
    title,
    message,
    data: {
      event: 'supplier_portal',
      orderId: String(order?._id || ''),
      orderNumber: order?.orderNumber || '',
      supplierId: supplierId || '',
      supplierName: order?.supplierName || '',
      portalStatus: order?.portalStatus || '',
      destinationStationId: toIdString(order?.destinationStationId),
      destinationStationName: order?.destinationStationName || '',
      carrierName: order?.carrierName || '',
      actorName: actor?.name || '',
      ...extraData,
    },
    recipients,
    priority: 'high',
    createdBy: actor?._id,
    orderId: order?._id,
    channels: ['in_app', 'push', 'email'],
  });
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDateForEmail(date) {
  if (!date) return '-';
  return new Date(date).toLocaleDateString('ar-SA', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

function formatMoneyForEmail(amount) {
  if (typeof amount !== 'number') return '-';
  return amount.toLocaleString('ar-SA', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function buildInactiveCustomerEmailTemplate({
  customer,
  summary,
  firstOrderDate,
  lastOrderDate,
  historyRangeText,
  historyDurationText,
  inactivityText,
}) {
  const hasOrders = Boolean(lastOrderDate);
  const customerName = escapeHtml(customer.name || '-');
  const customerCode = escapeHtml(customer.code || '-');
  const totalOrders = summary?.ordersCount ?? 0;

  return `
    <!doctype html>
    <html lang="ar" dir="rtl">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>تنبيه خمول العميل</title>
      </head>
      <body style="margin:0;background:#f5f7fb;font-family:Tahoma,Arial,sans-serif;color:#1f2937;">
        <div style="max-width:700px;margin:20px auto;background:#fff;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
          <div style="background:#0f4c81;color:#fff;padding:18px 20px;">
            <h2 style="margin:0;font-size:20px;">تنبيه خمول: لا يوجد طلب خلال آخر 7 أيام</h2>
          </div>

          <div style="padding:20px;">
            <p style="margin:0 0 12px 0;">عزيزي العميل <strong>${customerName}</strong> (${customerCode})،</p>
            <p style="margin:0 0 16px 0;">تم رصد عدم وجود طلبات جديدة لمدة <strong>${escapeHtml(inactivityText)}</strong>.</p>

            <div style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:10px;padding:14px;margin-bottom:14px;">
              <div style="font-weight:700;margin-bottom:8px;">ملخص النشاط</div>
              <div style="margin-bottom:6px;">إجمالي الطلبات السابقة: <strong>${escapeHtml(totalOrders)}</strong></div>
              <div style="margin-bottom:6px;">من: <strong>${escapeHtml(formatDateForEmail(firstOrderDate))}</strong> إلى: <strong>${escapeHtml(formatDateForEmail(lastOrderDate))}</strong></div>
              <div>الفترة بين أول وآخر طلب: <strong>${escapeHtml(historyDurationText)}</strong></div>
            </div>

            ${
              hasOrders
                ? `
            <div style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:10px;padding:14px;">
              <div style="font-weight:700;margin-bottom:8px;">آخر طلب مسجل</div>
              <div style="margin-bottom:6px;">رقم الطلب: <strong>${escapeHtml(summary.lastOrderNumber || '-')}</strong></div>
              <div style="margin-bottom:6px;">تاريخ الطلب: <strong>${escapeHtml(formatDateForEmail(lastOrderDate))}</strong></div>
              <div style="margin-bottom:6px;">نوع المنتج: <strong>${escapeHtml(summary.lastProductType || '-')}</strong></div>
              <div style="margin-bottom:6px;">نوع الوقود: <strong>${escapeHtml(summary.lastFuelType || '-')}</strong></div>
              <div style="margin-bottom:6px;">الكمية: <strong>${escapeHtml(summary.lastQuantity ?? '-')} ${escapeHtml(summary.lastUnit || '')}</strong></div>
              <div>إجمالي السعر: <strong>${escapeHtml(formatMoneyForEmail(summary.lastTotalPrice))}</strong></div>
            </div>
            `
                : `
            <div style="background:#fff7ed;border:1px solid #fed7aa;border-radius:10px;padding:14px;">
              لا يوجد أي طلب سابق مسجل لهذا العميل حتى الآن.
            </div>
            `
            }

            <p style="margin:16px 0 0 0;color:#6b7280;">نطاق تواريخ الطلبات: <strong>${escapeHtml(historyRangeText)}</strong></p>
          </div>
        </div>
      </body>
    </html>
  `;
}

exports.createOrder = async (req, res) => {
  try {
    upload(req, res, async (err) => {
      if (err) {
        return res.status(400).json({ error: err.message });
      }

      const orderData = { ...req.body };


      delete orderData.status;
      delete orderData.orderNumber;

      const supplierPortalSubmission =
        isSupplierPortalUser(req.user) ||
        String(orderData.entryChannel || '').trim() === 'supplier_portal';

      if (supplierPortalSubmission) {
        orderData.orderSource = 'مورد';
        orderData.entryChannel = 'supplier_portal';
        orderData.portalStatus = 'pending_review';
        orderData.carrierName = SUPPLIER_PORTAL_CARRIER;
        delete orderData.customer;

        if (isSupplierPortalUser(req.user)) {
          const linkedSupplierId = toIdString(req.user?.supplierId);
          if (!linkedSupplierId) {
            return res.status(400).json({
              error: 'لا يوجد مورد مرتبط بحساب المستخدم الحالي',
            });
          }
          orderData.supplier = linkedSupplierId;
        }
      } else {
        orderData.orderSource = orderData.customer ? 'عميل' : 'مورد';
        orderData.entryChannel = orderData.entryChannel === 'movement'
          ? 'movement'
          : 'manual';
      }

      if (orderData.orderSource !== 'مورد') {
        delete orderData.supplierOrderNumber;
        delete orderData.supplier;
      }


      if (orderData.orderSource === 'عميل' && !orderData.customer) {
        return res.status(400).json({
          error: 'العميل مطلوب لطلبات العملاء',
        });
      }

      const allowedRequestTypes = ['شراء', 'نقل'];

      if (orderData.orderSource === 'عميل') {
        orderData.requestType = orderData.requestType || 'شراء';

        if (!allowedRequestTypes.includes(orderData.requestType)) {
          return res.status(400).json({
            error: 'نوع العملية غير صحيح (يجب أن يكون شراء أو نقل)',
          });
        }
      } else {
        delete orderData.requestType;
      }

      if (supplierPortalSubmission) {
        delete orderData.requestType;
      }

 
      if (
        orderData.orderSource === 'عميل' &&
        orderData.requestType === 'نقل' &&
        !orderData.driver
      ) {
        return res.status(400).json({
          error: 'طلبات النقل تتطلب تعيين سائق',
        });
      }

      if (
        !orderData.loadingDate ||
        !orderData.loadingTime ||
        !orderData.arrivalDate ||
        !orderData.arrivalTime
      ) {
        return res.status(400).json({ error: 'جميع الأوقات مطلوبة' });
      }

      const loadingDateTime = new Date(
        `${orderData.loadingDate}T${orderData.loadingTime}`
      );
      const arrivalDateTime = new Date(
        `${orderData.arrivalDate}T${orderData.arrivalTime}`
      );

      if (arrivalDateTime <= loadingDateTime) {
        return res.status(400).json({
          error: 'وقت الوصول يجب أن يكون بعد وقت التحميل',
        });
      }


      orderData.createdBy = req.user._id;
      orderData.createdByName = req.user.name;

      if (supplierPortalSubmission) {
        orderData.portalReviewedAt = null;
        orderData.portalReviewedBy = null;
        orderData.portalReviewedByName = null;
        orderData.portalReviewNotes = null;
      }

      if (orderData.orderSource === 'عميل') {
        const customerDoc = await Customer.findById(orderData.customer);
        if (!customerDoc) {
          return res.status(400).json({ error: 'العميل غير موجود' });
        }

        orderData.customerName = customerDoc.name;
        orderData.customerCode = customerDoc.code;
        orderData.customerPhone = customerDoc.phone;
        orderData.customerEmail = customerDoc.email;
        orderData.customerAddress = orderData.customerAddress || customerDoc.address;

        orderData.city = orderData.city || customerDoc.city;
        orderData.area = orderData.area || customerDoc.area;
        orderData.address = orderData.address ?? null;
      }

      if (orderData.orderSource === 'مورد') {
        if (!orderData.supplier) {
          return res.status(400).json({ error: 'المورد مطلوب لطلبات المورد' });
        }

        const supplierDoc = await Supplier.findById(orderData.supplier);
        if (!supplierDoc) {
          return res.status(400).json({ error: 'المورد غير موجود' });
        }

        if (orderData.supplierOrderNumber) {
          const existingOrder = await Order.findOne({
            supplier: supplierDoc._id,
            supplierOrderNumber: orderData.supplierOrderNumber,
          }).select('_id orderNumber');
          if (existingOrder) {
            return res.status(400).json({
              error: 'رقم طلب المورد مستخدم من قبل لهذا المورد',
              existingOrderNumber: existingOrder.orderNumber,
            });
          }
        }

        orderData.supplierName = supplierDoc.name;
        orderData.supplierCompany = supplierDoc.company;
        orderData.supplierContactPerson = supplierDoc.contactPerson;
        orderData.supplierPhone = supplierDoc.phone;
        orderData.supplierEmail = supplierDoc.email || null;
        orderData.supplierAddress = orderData.supplierAddress || supplierDoc.address;

        orderData.city = orderData.city || supplierDoc.city;
        orderData.area = orderData.area || supplierDoc.area;
        orderData.address = orderData.address ?? null;
      }

      if (supplierPortalSubmission && orderData.portalCustomer) {
        const portalCustomerDoc = await Customer.findById(orderData.portalCustomer)
          .select('name supplier supplierStationIds');

        if (!portalCustomerDoc) {
          return res.status(400).json({ error: 'الجهة المطلوبة غير موجودة' });
        }

        const supplierId = toIdString(orderData.supplier);
        const customerSupplierId = toIdString(portalCustomerDoc.supplier);
        if (
          supplierId &&
          customerSupplierId &&
          customerSupplierId !== supplierId
        ) {
          return res.status(400).json({
            error: 'هذه الجهة غير مرتبطة بالمورد الحالي',
          });
        }

        orderData.portalCustomerName = portalCustomerDoc.name || '';
      }

      if (supplierPortalSubmission && orderData.destinationStationId) {
        const stationDoc = await Station.findById(orderData.destinationStationId)
          .select('stationName city location');

        if (!stationDoc) {
          return res.status(400).json({ error: 'المحطة المختارة غير موجودة' });
        }

        if (orderData.portalCustomer) {
          const portalCustomerDoc = await Customer.findById(orderData.portalCustomer)
            .select('supplierStationIds');
          const allowedStations = new Set(
            (portalCustomerDoc?.supplierStationIds || []).map((value) => toIdString(value))
          );
          if (allowedStations.size > 0 && !allowedStations.has(toIdString(stationDoc._id))) {
            return res.status(400).json({
              error: 'المحطة المختارة غير مرتبطة بهذه الجهة',
            });
          }
        }

        orderData.destinationStationName =
          orderData.destinationStationName || stationDoc.stationName;
        orderData.city = orderData.city || stationDoc.city;
        orderData.area = orderData.area || stationDoc.stationName;
        orderData.address = orderData.address || stationDoc.location || stationDoc.stationName;
      }

      if (!orderData.city || !orderData.area) {
        return res.status(400).json({
          error: 'المدينة والمنطقة مطلوبة لإنشاء الطلب',
          debug: {
            city: orderData.city,
            area: orderData.area,
          },
        });
      }


      orderData.orderDate = new Date(orderData.orderDate || new Date());
      orderData.loadingDate = new Date(orderData.loadingDate);
      orderData.arrivalDate = new Date(orderData.arrivalDate);

      const remoteAttachments = parseRemoteAttachments(
        req.body.attachmentUrls,
        req.user,
        'order-attachment'
      );
      const localAttachments = (req.files?.attachments || []).map((file) => ({
        filename: file.originalname,
        path: file.path,
        uploadedAt: new Date(),
        uploadedBy: req.user._id,
      }));

      if (remoteAttachments.length || localAttachments.length) {
        orderData.attachments = [...remoteAttachments, ...localAttachments];
      }

      const order = new Order(orderData);

      try {
        await order.save();
      } catch (error) {

        if (
          error.code === 11000 &&
          (
            error.keyPattern?.supplierOrderNumber ||
            error.keyPattern?.supplier ||
            error.keyValue?.supplierOrderNumber
          )
        ) {
          return res.status(400).json({
            error: 'رقم طلب المورد مستخدم من قبل لهذا المورد'
          });
        }

        console.error('❌ Error saving order:', error);
        return res.status(500).json({
          error: 'فشل في حفظ الطلب'
        });
      }

      const populatedOrder = await Order.findById(order._id)
        .populate('customer', 'name code phone city area email')
        .populate('supplier', 'name company city area email contactPerson phone')
        .populate('createdBy', 'name email')
        .populate('driver', 'name phone vehicleNumber')
        .populate('portalCustomer', 'name code')
        .populate('destinationStationId', 'stationName stationCode city');

      const createOrderCreationEmailTemplate = (order, user) => {
        const formatDate = (date) => {
          if (!date) return 'غير محدد';
          return new Date(date).toLocaleDateString('ar-SA', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          });
        };

        const formatTime = (time) => time || 'غير محدد';
        
        const formatCurrency = (amount) => {
          if (!amount) return '0.00 ريال';
          return amount.toLocaleString('ar-SA', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
          }) + ' ريال';
        };

        const getOrderTypeIcon = () => {
          if (order.orderSource === 'عميل') {
            return order.requestType === 'نقل' ? '🚚' : '🛒';
          }
          return '🏭';
        };

        const getOrderTypeText = () => {
          if (order.orderSource === 'عميل') {
            return order.requestType === 'نقل' ? 'طلب نقل' : 'طلب شراء';
          }
          return 'طلب مورد';
        };

        return `
          <!DOCTYPE html>
          <html dir="rtl" lang="ar">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>${getOrderTypeIcon()} ${getOrderTypeText()} جديد - نظام إدارة الطلبات</title>
              <style>
                  * {
                      margin: 0;
                      padding: 0;
                      box-sizing: border-box;
                      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                  }
                  
                  body {
                      background-color: #f5f7fa;
                      line-height: 1.6;
                      color: #333;
                  }
                  
                  .email-container {
                      max-width: 700px;
                      margin: 20px auto;
                      background-color: #ffffff;
                      border-radius: 12px;
                      overflow: hidden;
                      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08);
                  }
                  
                  .header {
                      background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
                      color: white;
                      padding: 30px;
                      text-align: center;
                      border-bottom: 4px solid #ffcc00;
                  }
                  
                  .company-logo {
                      font-size: 24px;
                      font-weight: bold;
                      margin-bottom: 15px;
                      color: #ffcc00;
                  }
                  
                  .header h1 {
                      font-size: 26px;
                      margin-bottom: 10px;
                      font-weight: 700;
                  }
                  
                  .header .subtitle {
                      font-size: 16px;
                      opacity: 0.9;
                      margin-top: 5px;
                  }
                  
                  .order-number-badge {
                      background: #4CAF50;
                      color: white;
                      padding: 10px 25px;
                      border-radius: 25px;
                      display: inline-block;
                      margin-top: 15px;
                      font-weight: bold;
                      font-size: 18px;
                      letter-spacing: 1px;
                  }
                  
                  .content {
                      padding: 30px;
                  }
                  
                  .summary-card {
                      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                      color: white;
                      padding: 25px;
                      border-radius: 10px;
                      margin-bottom: 30px;
                      text-align: center;
                  }
                  
                  .summary-card h3 {
                      font-size: 22px;
                      margin-bottom: 10px;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      gap: 10px;
                  }
                  
                  .summary-details {
                      display: grid;
                      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                      gap: 15px;
                      margin-top: 20px;
                  }
                  
                  .summary-item {
                      background: rgba(255, 255, 255, 0.1);
                      padding: 15px;
                      border-radius: 8px;
                      backdrop-filter: blur(10px);
                  }
                  
                  .section {
                      margin-bottom: 30px;
                      padding: 20px;
                      border-radius: 10px;
                      background-color: #f8f9fa;
                      border-left: 4px solid #2a5298;
                  }
                  
                  .section-title {
                      color: #2d3748;
                      font-size: 18px;
                      margin-bottom: 15px;
                      padding-bottom: 10px;
                      border-bottom: 2px solid #e2e8f0;
                      font-weight: 600;
                      display: flex;
                      align-items: center;
                      gap: 10px;
                  }
                  
                  .info-grid {
                      display: grid;
                      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                      gap: 15px;
                      margin-top: 15px;
                  }
                  
                  .info-item {
                      background: white;
                      padding: 15px;
                      border-radius: 8px;
                      box-shadow: 0 2px 6px rgba(0,0,0,0.05);
                  }
                  
                  .info-label {
                      color: #718096;
                      font-size: 13px;
                      margin-bottom: 5px;
                      font-weight: 500;
                  }
                  
                  .info-value {
                      color: #2d3748;
                      font-size: 15px;
                      font-weight: 600;
                  }
                  
                  .timeline {
                      position: relative;
                      padding: 20px 0;
                  }
                  
                  .timeline-item {
                      position: relative;
                      padding: 12px 0 12px 30px;
                      margin-bottom: 15px;
                      background: white;
                      border-radius: 8px;
                      padding: 15px 15px 15px 40px;
                  }
                  
                  .timeline-item:before {
                      content: '';
                      position: absolute;
                      left: 15px;
                      top: 20px;
                      width: 10px;
                      height: 10px;
                      border-radius: 50%;
                      background: #2a5298;
                  }
                  
                  .timeline-item:after {
                      content: '';
                      position: absolute;
                      left: 19px;
                      top: 20px;
                      width: 2px;
                      height: calc(100% + 15px);
                      background: #e2e8f0;
                  }
                  
                  .timeline-item:last-child:after {
                      display: none;
                  }
                  
                  .footer {
                      background: #1a202c;
                      color: white;
                      padding: 25px;
                      text-align: center;
                      margin-top: 30px;
                      border-top: 4px solid #ffcc00;
                  }
                  
                  .footer p {
                      margin: 10px 0;
                      opacity: 0.8;
                  }
                  
                  .footer-logo {
                      font-size: 22px;
                      font-weight: bold;
                      color: #ffcc00;
                      margin-bottom: 10px;
                  }
                  
                  .status-badge {
                      display: inline-block;
                      padding: 4px 12px;
                      border-radius: 20px;
                      font-size: 12px;
                      font-weight: 600;
                  }
                  
                  .status-new {
                      background: #d4edda;
                      color: #155724;
                  }
                  
                  .action-button {
                      display: inline-block;
                      background: #2a5298;
                      color: white;
                      padding: 12px 30px;
                      border-radius: 25px;
                      text-decoration: none;
                      font-weight: 600;
                      margin: 20px 0;
                      transition: all 0.3s ease;
                  }
                  
                  .action-button:hover {
                      background: #1e3c72;
                      transform: translateY(-2px);
                      box-shadow: 0 4px 12px rgba(42, 82, 152, 0.3);
                  }
                  
                  .contact-info {
                      background: #f0f9ff;
                      padding: 15px;
                      border-radius: 8px;
                      margin-top: 15px;
                      border-right: 4px solid #2a5298;
                  }
                  
                  @media (max-width: 600px) {
                      .content {
                          padding: 20px;
                      }
                      
                      .header {
                          padding: 20px 15px;
                      }
                      
                      .header h1 {
                          font-size: 20px;
                      }
                      
                      .info-grid {
                          grid-template-columns: 1fr;
                      }
                      
                      .summary-details {
                          grid-template-columns: 1fr;
                      }
                      
                      .order-number-badge {
                          font-size: 16px;
                          padding: 8px 20px;
                      }
                  }
              </style>
          </head>
          <body>
              <div class="email-container">
                  <div class="header">
                      <div class="company-logo">شركة البحيرة العربية</div>
                      <h1>${getOrderTypeIcon()} ${getOrderTypeText()} جديد</h1>
                      <p class="subtitle">نظام إدارة الطلبات - تأكيد إنشاء طلب</p>
                      <div class="order-number-badge">${order.orderNumber}</div>
                  </div>
                  
                  <div class="content">
                      <div class="summary-card">
                          <h3>${getOrderTypeIcon()} ملخص الطلب الجديد</h3>
                          <div class="summary-details">
                              <div class="summary-item">
                                  <div class="info-label">نوع الطلب</div>
                                  <div class="info-value">${getOrderTypeText()}</div>
                              </div>
                              <div class="summary-item">
                                  <div class="info-label">تاريخ الإنشاء</div>
                                  <div class="info-value">${formatDate(new Date())}</div>
                              </div>
                              <div class="summary-item">
                                  <div class="info-label">الحالة</div>
                                  <div class="info-value">
                                      <span class="status-badge status-new">🆕 جديد</span>
                                  </div>
                              </div>
                          </div>
                      </div>
                      
                      <div class="section">
                          <h2 class="section-title">👤 معلومات ${order.orderSource === 'عميل' ? 'العميل' : 'المورد'}</h2>
                          <div class="info-grid">
                              <div class="info-item">
                                  <div class="info-label">${order.orderSource === 'عميل' ? 'اسم العميل' : 'اسم المورد'}</div>
                                  <div class="info-value">${order.orderSource === 'عميل' ? order.customerName : order.supplierName}</div>
                              </div>
                              
                              ${order.orderSource === 'عميل' ? `
                              <div class="info-item">
                                  <div class="info-label">كود العميل</div>
                                  <div class="info-value">${order.customerCode || 'غير محدد'}</div>
                              </div>
                              ` : `
                              <div class="info-item">
                                  <div class="info-label">الشركة</div>
                                  <div class="info-value">${order.supplierCompany || 'غير محدد'}</div>
                              </div>
                              `}
                              
                              <div class="info-item">
                                  <div class="info-label">📞 الهاتف</div>
                                  <div class="info-value">${order.orderSource === 'عميل' ? order.customerPhone : order.supplierPhone}</div>
                              </div>
                              
                              ${order.orderSource === 'عميل' && order.customerEmail ? `
                              <div class="info-item">
                                  <div class="info-label">✉️ الإيميل</div>
                                  <div class="info-value">${order.customerEmail}</div>
                              </div>
                              ` : ''}
                              
                              ${order.orderSource === 'مورد' && order.supplierContactPerson ? `
                              <div class="info-item">
                                  <div class="info-label">الشخص المسؤول</div>
                                  <div class="info-value">${order.supplierContactPerson}</div>
                              </div>
                              ` : ''}
                          </div>
                      </div>
                      
                      <div class="section">
                          <h2 class="section-title">📍 معلومات الموقع</h2>
                          <div class="info-grid">
                              <div class="info-item">
                                  <div class="info-label">المدينة</div>
                                  <div class="info-value">${order.city || 'غير محدد'}</div>
                              </div>
                              <div class="info-item">
                                  <div class="info-label">المنطقة</div>
                                  <div class="info-value">${order.area || 'غير محدد'}</div>
                              </div>
                              ${order.address ? `
                              <div class="info-item">
                                  <div class="info-label">العنوان التفصيلي</div>
                                  <div class="info-value">${order.address}</div>
                              </div>
                              ` : ''}
                          </div>
                      </div>
                      
                      ${order.orderSource === 'عميل' && order.requestType ? `
                      <div class="section">
                          <h2 class="section-title">📦 معلومات الطلب</h2>
                          <div class="info-grid">
                              <div class="info-item">
                                  <div class="info-label">نوع العملية</div>
                                  <div class="info-value">${order.requestType}</div>
                              </div>
                              ${order.quantity ? `
                              <div class="info-item">
                                  <div class="info-label">الكمية</div>
                                  <div class="info-value">${order.quantity} ${order.unit || 'لتر'}</div>
                              </div>
                              ` : ''}
                              ${order.productType ? `
                              <div class="info-item">
                                  <div class="info-label">نوع المنتج</div>
                                  <div class="info-value">${order.productType}</div>
                              </div>
                              ` : ''}
                              ${order.fuelType ? `
                              <div class="info-item">
                                  <div class="info-label">نوع الوقود</div>
                                  <div class="info-value">${order.fuelType}</div>
                              </div>
                              ` : ''}
                          </div>
                      </div>
                      ` : ''}
                      
                      <div class="section">
                          <h2 class="section-title">⏰ الجدول الزمني</h2>
                          <div class="timeline">
                              <div class="timeline-item">
                                  <strong>وقت التحميل:</strong><br>
                                  ${formatDate(order.loadingDate)} - ${order.loadingTime}
                              </div>
                              <div class="timeline-item">
                                  <strong>وقت الوصول المتوقع:</strong><br>
                                  ${formatDate(order.arrivalDate)} - ${order.arrivalTime}
                              </div>
                              <div class="timeline-item">
                                  <strong>تم الإنشاء في:</strong><br>
                                  ${formatDate(new Date())} - ${new Date().toLocaleTimeString('ar-SA', {hour: '2-digit', minute:'2-digit'})}
                              </div>
                          </div>
                      </div>
                      
                      <div class="section">
                          <h2 class="section-title">👷 معلومات الإنشاء</h2>
                          <div class="info-grid">
                              <div class="info-item">
                                  <div class="info-label">تم الإنشاء بواسطة</div>
                                  <div class="info-value">${user.name}</div>
                              </div>
                              <div class="info-item">
                                  <div class="info-label">📧 إيميل المنشئ</div>
                                  <div class="info-value">${user.email}</div>
                              </div>
                              <div class="info-item">
                                  <div class="info-label">تاريخ الإنشاء</div>
                                  <div class="info-value">${formatDate(new Date())}</div>
                              </div>
                              <div class="info-item">
                                  <div class="info-label">وقت الإنشاء</div>
                                  <div class="info-value">${new Date().toLocaleTimeString('ar-SA', {hour: '2-digit', minute:'2-digit'})}</div>
                              </div>
                          </div>
                      </div>
                      
                      ${order.notes ? `
                      <div class="section">
                          <h2 class="section-title">📝 ملاحظات إضافية</h2>
                          <div class="contact-info">
                              <p style="font-size: 14px; line-height: 1.6; color: #2c5282;">${order.notes}</p>
                          </div>
                      </div>
                      ` : ''}
                      
                      <div style="text-align: center; margin: 30px 0;">
                          <a href="#" class="action-button">👁️ عرض تفاصيل الطلب</a>
                          <p style="color: #718096; font-size: 13px; margin-top: 15px;">
                              يمكنك تتبع حالة الطلب عبر لوحة التحكم في النظام
                          </p>
                      </div>
                      
                      <div class="contact-info">
                          <h4 style="color: #2a5298; margin-bottom: 10px;">📞 للاستفسار والدعم</h4>
                          <p style="font-size: 14px; margin-bottom: 5px;">
                              <strong>شركة البحيرة العربية</strong><br>
                              نظام إدارة الطلبات المتكامل
                          </p>
                          <p style="font-size: 13px; color: #4a5568;">
                              هذه رسالة تلقائية، يرجى عدم الرد عليها مباشرة
                          </p>
                      </div>
                  </div>
                  
                  <div class="footer">
                      <div class="footer-logo">شركة البحيرة العربية</div>
                      <p>نظام إدارة الطلبات المتكامل</p>
                      <p>© ${new Date().getFullYear()} جميع الحقوق محفوظة</p>
                      <p style="font-size: 12px; opacity: 0.6; margin-top: 15px;">
                          تم إرسال هذه الرسالة تلقائيًا من النظام، يرجى التواصل مع فريق الدعم لأي استفسار
                      </p>
                  </div>
              </div>
          </body>
          </html>
        `;
      };


      try {
        const emails = await getOrderEmails(order);

        if (emails && emails.length > 0) {

          const emailPromise = sendEmail({
            to: emails,
            subject:
              order.orderSource === 'عميل'
                ? `🆕 طلب عميل جديد تم إنشاؤه (${order.orderNumber}) - شركة البحيرة العربية`
                : `🆕 طلب مورد جديد تم إنشاؤه (${order.orderNumber}) - شركة البحيرة العربية`,
            html: createOrderCreationEmailTemplate(order, req.user),
          });


          emailPromise
            .then(() => {
              console.log(`✅ Email sent successfully for order ${order.orderNumber}`);
            })
            .catch((emailError) => {
              console.warn(`⚠️ Email sending warning for ${order.orderNumber}:`, emailError.message);

            });
        }
      } catch (emailError) {
        console.warn(`⚠️ Email warning for ${order.orderNumber}:`, emailError.message);

      }


      if (toIdString(populatedOrder?.driver)) {
        await sendDriverAssignmentNotification({ order: populatedOrder, actor: req.user });
      }

      await Activity.create({
        orderId: order._id,
        activityType: 'إنشاء',
        description: supplierPortalSubmission
          ? `تم إنشاء طلب مورد عبر بوابة الموردين ${order.orderNumber}`
          : `تم إنشاء الطلب ${order.orderNumber}`,
        performedBy: req.user._id,
        performedByName: req.user.name,
        changes: {
          'قناة الإدخال': supplierPortalSubmission ? 'بوابة الموردين' : order.entryChannel,
          ...(order.portalStatus ? { 'حالة المراجعة': order.portalStatus } : {}),
          ...(order.destinationStationName
            ? { 'محطة التفريغ': order.destinationStationName }
            : {}),
          ...(order.carrierName ? { 'الناقل': order.carrierName } : {}),
        },
      });

      if (supplierPortalSubmission) {
        await notifySupplierPortal({
          order: populatedOrder,
          actor: req.user,
          title: 'طلب مورد جديد بانتظار المراجعة',
          message: [
            `تمت إضافة الطلب ${order.orderNumber}`,
            order.supplierName ? `المورد: ${order.supplierName}` : '',
            order.destinationStationName
              ? `محطة التفريغ: ${order.destinationStationName}`
              : '',
          ].filter(Boolean).join(' • '),
          type: 'order_created',
          includeReviewRoles: true,
          extraData: {
            portalStatus: order.portalStatus || 'pending_review',
          },
        });
      }

      return res.status(201).json({
        message:
          supplierPortalSubmission
            ? 'تم إرسال طلب المورد للمراجعة بنجاح'
            : order.orderSource === 'عميل'
            ? 'تم إنشاء طلب العميل بنجاح'
            : 'تم إنشاء طلب المورد بنجاح',
        order: populatedOrder,
        emailSent: true
      });
    });
  } catch (error) {
    console.error('❌ Error creating order:', error);
    return res.status(500).json({ 
      error: 'حدث خطأ في السيرفر',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};



exports.getOrders = async (req, res) => {
  try {
     const hasPagination = req.query.page || req.query.limit;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 0; 
    const skip = limit ? (page - 1) * limit : 0;


    const filter = {};

    if (userRequiresAssignedOrdersOnly(req.user)) {
      const linkedDriverId = await resolveLinkedDriverId(req.user);
      const includeHistory = String(req.query.includeHistory || '').trim() === 'true';
      Object.assign(filter, buildAssignedOrdersFilter(linkedDriverId, { includeHistory }));
    }

    if (isSupplierPortalUser(req.user)) {
      const supplierId = toIdString(req.user?.supplierId);
      if (!supplierId) {
        return res.status(403).json({ error: 'لا يوجد مورد مرتبط بالمستخدم الحالي' });
      }
      filter.supplier = supplierId;
    }
    
    // تصفية حسب مصدر الطلب
    if (req.query.orderSource) {
      filter.orderSource = req.query.orderSource;
    }
    
    // تصفية حسب حالة الدمج
    if (req.query.mergeStatus) {
      filter.mergeStatus = req.query.mergeStatus;
    }

    if (req.query.entryChannel) {
      filter.entryChannel = req.query.entryChannel;
    }

    if (req.query.movementState) {
      filter.movementState = req.query.movementState;
    }

    if (req.query.portalStatus) {
      filter.portalStatus = req.query.portalStatus;
    }
    
    if (req.query.status) {
      filter.status = req.query.status;
    }
    
    if (req.query.supplierName) {
      filter.supplierName = new RegExp(req.query.supplierName, 'i');
    }
    
    if (req.query.customerName) {
      filter.customerName = new RegExp(req.query.customerName, 'i');
    }
    
    if (req.query.orderNumber) {
      filter.orderNumber = new RegExp(req.query.orderNumber, 'i');
    }
    
    if (req.query.supplierOrderNumber) {
      filter.supplierOrderNumber = new RegExp(req.query.supplierOrderNumber, 'i');
    }

    if (req.query.carrierName) {
      filter.carrierName = new RegExp(req.query.carrierName, 'i');
    }

    if (req.query.destinationStationId) {
      filter.destinationStationId = req.query.destinationStationId;
    }

    if (req.query.portalCustomer) {
      filter.portalCustomer = req.query.portalCustomer;
    }

    if (req.query.supplierId && !isSupplierPortalUser(req.user)) {
      filter.supplier = req.query.supplierId;
    }
    
    if (req.query.city) {
      filter.city = new RegExp(req.query.city, 'i');
    }
    
    if (req.query.area) {
      filter.area = new RegExp(req.query.area, 'i');
    }
    
    if (req.query.productType) {
      filter.productType = req.query.productType;
    }
    
    if (req.query.fuelType) {
      filter.fuelType = req.query.fuelType;
    }
    
    if (req.query.paymentStatus) {
      filter.paymentStatus = req.query.paymentStatus;
    }
    
    if (req.query.driverName) {
      filter.driverName = new RegExp(req.query.driverName, 'i');
    }
    
    if (req.query.createdByName) {
      filter.createdByName = new RegExp(req.query.createdByName, 'i');
    }
    
    // تصفية حسب التواريخ
    if (req.query.startDate || req.query.endDate) {
      const dateField = req.query.dateField || 'orderDate';
      filter[dateField] = {};
      
      if (req.query.startDate) {
        const startDate = new Date(req.query.startDate);
        startDate.setHours(0, 0, 0, 0);
        filter[dateField].$gte = startDate;
      }
      
      if (req.query.endDate) {
        const endDate = new Date(req.query.endDate);
        endDate.setHours(23, 59, 59, 999);
        filter[dateField].$lte = endDate;
      }
    }

    // تصفية حسب حالة التحميل/التوصيل
    if (req.query.isOverdue) {
      const now = new Date();
      if (req.query.isOverdue === 'arrival') {
        filter.$expr = {
          $lt: [
            {
              $dateFromParts: {
                year: { $year: '$arrivalDate' },
                month: { $month: '$arrivalDate' },
                day: { $dayOfMonth: '$arrivalDate' },
                hour: { $toInt: { $arrayElemAt: [{ $split: ['$arrivalTime', ':'] }, 0] } },
                minute: { $toInt: { $arrayElemAt: [{ $split: ['$arrivalTime', ':'] }, 1] } }
              }
            },
            now
          ]
        };
      } else if (req.query.isOverdue === 'loading') {
        filter.$expr = {
          $lt: [
            {
              $dateFromParts: {
                year: { $year: '$loadingDate' },
                month: { $month: '$loadingDate' },
                day: { $dayOfMonth: '$loadingDate' },
                hour: { $toInt: { $arrayElemAt: [{ $split: ['$loadingTime', ':'] }, 0] } },
                minute: { $toInt: { $arrayElemAt: [{ $split: ['$loadingTime', ':'] }, 1] } }
              }
            },
            now
          ]
        };
      }
    }

    const orders = await Order.find(filter)
      .populate('customer', 'name code phone email city area address')
      .populate('supplier', 'name company contactPerson phone email address city area')
      .populate('createdBy', 'name email role')
      .populate('driver', 'name phone vehicleNumber licenseNumber')
      .populate('portalCustomer', 'name code')
      .populate('destinationStationId', 'stationName stationCode city')
      .populate('mergedWithOrderId', 'orderNumber customerName supplierName')
      .sort({ orderDate: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const mergedOrderIds = orders
      .filter((order) => order.orderSource === 'مدمج')
      .map((order) => order._id);

    let mergedRequestTypeMap = {};
    if (mergedOrderIds.length > 0) {
      const mergedCustomerOrders = await Order.find({
        mergedWithOrderId: { $in: mergedOrderIds },
        orderSource: 'عميل',
      })
        .select('mergedWithOrderId requestType')
        .lean();

      mergedCustomerOrders.forEach((order) => {
        if (order.mergedWithOrderId && order.requestType) {
          mergedRequestTypeMap[order.mergedWithOrderId.toString()] =
            order.requestType;
        }
      });
    }

    // معالجة كل طلب للحصول على معلومات إضافية
    const ordersWithDisplayInfo = await Promise.all(
      orders.map(async (order) => {
        const orderObject = order.toObject();

        if (orderObject.orderSource === 'مدمج') {
          const currentType = orderObject.requestType;
          if (!currentType || !currentType.toString().trim()) {
            const derivedType =
              mergedRequestTypeMap[orderObject._id.toString()];
            if (derivedType) {
              orderObject.requestType = derivedType;
            }
          }
        }

        // الحصول على معلومات العرض الأساسية
        const displayInfo = order.getDisplayInfo ? order.getDisplayInfo() : {
          orderNumber: order.orderNumber,
          orderSource: order.orderSource,
          orderSourceText: getOrderSourceText(order.orderSource),
          supplierName: order.supplierName || 'غير محدد',
          customerName: order.customerName || 'غير محدد',
          status: order.status,
          statusColor: getStatusColor(order.status),
          location: getLocation(order),
          fuelType: order.fuelType,
          quantity: order.quantity,
          unit: order.unit,
          mergeStatus: order.mergeStatus,
          totalPrice: order.totalPrice,
          paymentStatus: order.paymentStatus,
          createdAt: order.createdAt
        };

        // حساب المؤقتات
        let arrivalCountdown = 'غير متاح';
        let loadingCountdown = 'غير متاح';
        let isArrivalOverdue = false;
        let isLoadingOverdue = false;

        if (order.getFullArrivalDateTime) {
          const arrivalDateTime = order.getFullArrivalDateTime();
          const now = new Date();
          const arrivalRemaining = arrivalDateTime - now;
          
          if (arrivalRemaining <= 0) {
            arrivalCountdown = 'تأخر';
            isArrivalOverdue = true;
          } else {
            arrivalCountdown = formatDuration(arrivalRemaining);
          }
        }

        if (order.getFullLoadingDateTime) {
          const loadingDateTime = order.getFullLoadingDateTime();
          const now = new Date();
          const loadingRemaining = loadingDateTime - now;
          
          if (loadingRemaining <= 0) {
            loadingCountdown = 'تأخر';
            isLoadingOverdue = true;
          } else {
            loadingCountdown = formatDuration(loadingRemaining);
          }
        }

        // الحصول على معلومات الطرف المدمج معه
        let mergePartnerInfo = null;
        if (order.mergedWithOrderId && typeof order.mergedWithOrderId === 'object') {
          mergePartnerInfo = {
            orderNumber: order.mergedWithOrderId.orderNumber,
            name: order.orderSource === 'مورد' 
              ? order.mergedWithOrderId.customerName 
              : order.mergedWithOrderId.supplierName,
            type: order.orderSource === 'مورد' ? 'عميل' : 'مورد'
          };
        } else if (order.mergedWithInfo) {
          mergePartnerInfo = order.mergedWithInfo;
        }

        // الحصول على معلومات إضافية حسب نوع الطلب
        let additionalInfo = {};
        
        if (order.orderSource === 'مورد') {
          additionalInfo = {
            supplierOrder: {
              orderNumber: order.orderNumber,
              supplierName: order.supplierName,
              supplierCompany: order.supplierCompany,
              supplierPhone: order.supplierPhone,
              status: order.status,
              mergeStatus: order.mergeStatus,
              mergedWith: mergePartnerInfo
            }
          };
        } else if (order.orderSource === 'عميل') {
          additionalInfo = {
            customerOrder: {
              orderNumber: order.orderNumber,
              customerName: order.customerName,
              customerCode: order.customerCode,
              customerPhone: order.customerPhone,
              requestType: order.requestType,
              status: order.status,
              mergeStatus: order.mergeStatus,
              mergedWith: mergePartnerInfo
            }
          };
        } else if (order.orderSource === 'مدمج') {
          additionalInfo = {
            mergedOrder: {
              orderNumber: order.orderNumber,
              supplierName: order.supplierName,
              customerName: order.customerName,
              quantity: order.quantity,
              unit: order.unit,
              status: order.status,
              mergeStatus: order.mergeStatus
            }
          };
        }

        return {
          ...orderObject,
          displayInfo: {
            ...displayInfo,
            arrivalCountdown,
            loadingCountdown,
            isArrivalOverdue,
            isLoadingOverdue
          },
          mergePartnerInfo,
          additionalInfo,
          timelines: {
            orderDate: order.orderDate,
            loadingDate: order.loadingDate,
            arrivalDate: order.arrivalDate,
            loadingTime: order.loadingTime,
            arrivalTime: order.arrivalTime,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt,
            mergedAt: order.mergedAt,
            completedAt: order.completedAt
          },
          financials: {
            unitPrice: order.unitPrice,
            totalPrice: order.totalPrice,
            paymentMethod: order.paymentMethod,
            paymentStatus: order.paymentStatus,
            driverEarnings: order.driverEarnings
          },
          logistics: {
            driverName: order.driverName,
            driverPhone: order.driverPhone,
            vehicleNumber: order.vehicleNumber,
            deliveryDuration: order.deliveryDuration,
            distance: order.distance
          }
        };
      })
    );

    // الحصول على العدد الإجمالي
    const total = await Order.countDocuments(filter);
    const stats = {
  totalOrders: total,
  bySource: {
    supplier: await Order.countDocuments({
      ...filter,
      orderSource: 'مورد'
    }),

    customer: await Order.countDocuments({
      ...filter,
      $or: [
        { orderSource: 'عميل' },
        { orderSource: 'مدمج', customer: { $ne: null } }
      ]
    }),

    merged: await Order.countDocuments({
      ...filter,
      orderSource: 'مدمج'
    })
  },

      byStatus: {
        pending: await Order.countDocuments({ 
          ...filter, 
          status: { 
            $in: ['في المستودع', 'في انتظار التخصيص', 'في انتظار الدمج'] 
          } 
        }),
        inProgress: await Order.countDocuments({ 
          ...filter, 
          status: { 
            $in: ['تم الإنشاء', 'تم تخصيص طلب المورد', 'تم دمجه مع العميل', 
                  'تم دمجه مع المورد', 'جاهز للتحميل', 'في انتظار التحميل'] 
          } 
        }),
        active: await Order.countDocuments({ 
          ...filter, 
          status: { 
            $in: ['تم التحميل', 'في الطريق'] 
          } 
        }),
        completed: await Order.countDocuments({ 
          ...filter, 
          status: { 
            $in: ['تم التسليم', 'تم التنفيذ', 'مكتمل'] 
          } 
        }),
        cancelled: await Order.countDocuments({ 
          ...filter, 
          status: 'ملغى' 
        })
      }
    };

    res.json({
      success: true,
      orders: ordersWithDisplayInfo,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      },
      stats,
      filters: req.query
    });
  } catch (error) {
    console.error('Error getting orders:', error);
    res.status(500).json({ 
      success: false,
      error: 'حدث خطأ في السيرفر',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// ============================================
// 🔧 دوال مساعدة محلية
// ============================================

function getOrderSourceText(orderSource) {
  switch(orderSource) {
    case 'مورد': return 'طلب مورد';
    case 'عميل': return 'طلب عميل';
    case 'مدمج': return 'طلب مدمج';
    default: return 'طلب';
  }
}

function getStatusColor(status) {
  const statusColors = {
    // طلبات المورد
    'في المستودع': '#ff9800',
    'تم الإنشاء': '#2196f3',
    'في انتظار الدمج': '#ff5722',
    'تم دمجه مع العميل': '#9c27b0',
    'جاهز للتحميل': '#00bcd4',
    'تم التحميل': '#4caf50',
    'في الطريق': '#3f51b5',
    'تم التسليم': '#8bc34a',
    
    // طلبات العميل
    'في انتظار التخصيص': '#ff9800',
    'تم تخصيص طلب المورد': '#2196f3',
    'في انتظار الدمج': '#ff5722',
    'تم دمجه مع المورد': '#9c27b0',
    'في انتظار التحميل': '#00bcd4',
    'في الطريق': '#3f51b5',
    'تم التسليم': '#8bc34a',
    
    // طلبات مدمجة
    'تم الدمج': '#9c27b0',
    'مخصص للعميل': '#2196f3',
    'جاهز للتحميل': '#00bcd4',
    'تم التحميل': '#4caf50',
    'في الطريق': '#3f51b5',
    'تم التسليم': '#8bc34a',
    'تم التنفيذ': '#4caf50',
    
    // عامة
    'ملغى': '#f44336',
    'مكتمل': '#8bc34a'
  };
  
  return statusColors[status] || '#757575';
}

function getLocation(order) {
  if (order.city && order.area) {
    return `${order.city} - ${order.area}`;
  }
  return order.city || order.area || 'غير محدد';
}

function formatDuration(milliseconds) {
  const totalSeconds = Math.floor(milliseconds / 1000);
  const days = Math.floor(totalSeconds / (3600 * 24));
  const hours = Math.floor((totalSeconds % (3600 * 24)) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  
  const parts = [];
  if (days > 0) parts.push(`${days} يوم`);
  if (hours > 0) parts.push(`${hours} ساعة`);
  if (minutes > 0) parts.push(`${minutes} دقيقة`);
  
  return parts.join(' و ') || 'أقل من دقيقة';
}
// ============================================
// 🔍 جلب طلب محدد
// ============================================

exports.getOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('customer', 'name code phone email city area address')
      .populate('supplier', 'name company contactPerson phone address email')
      .populate('createdBy', 'name email')
      .populate('driver', 'name phone vehicleNumber licenseNumber')
      .populate('portalCustomer', 'name code')
      .populate('destinationStationId', 'stationName stationCode city')
      .populate('originalOrderId', 'orderNumber orderSource customerName')
      .populate('mergedOrderId', 'orderNumber orderSource customerName');
    
    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    if (userRequiresAssignedOrdersOnly(req.user)) {
      const canAccessOrder = await userCanAccessOrder(req.user, order);
      if (!canAccessOrder) {
        return res.status(403).json({ error: 'هذا الطلب غير مخصص لك' });
      }
    }

    if (!(await ensureSupplierPortalOrderAccess(req.user, order))) {
      return res.status(403).json({ error: 'هذا الطلب غير متاح لك' });
    }

    let supplierSourceOrder = null;

    if (order.orderSource === 'مدمج') {
      const currentType = order.requestType;
      if (!currentType || !currentType.toString().trim()) {
        const customerOrder = await Order.findOne({
          mergedWithOrderId: order._id,
          orderSource: 'عميل',
        })
          .select('requestType')
          .lean();

        if (customerOrder?.requestType) {
          order.requestType = customerOrder.requestType;
        }
      }

      supplierSourceOrder = await Order.findOne({
        mergedWithOrderId: order._id,
        orderSource: 'مورد',
      })
        .select('orderNumber attachments')
        .lean();
    }

    // جلب النشاطات لهذا الطلب
    const activities = await Activity.find({ orderId: order._id })
      .populate('performedBy', 'name')
      .sort({ createdAt: -1 });

    // جلب الطلبات المرتبطة (إذا كان مدمج)
    let relatedOrders = [];
    if (order.mergeStatus === 'مدمج' && order.mergedOrderId) {
      relatedOrders = await Order.find({
        $or: [
          { originalOrderId: order._id },
          { mergedOrderId: order._id }
        ]
      }).populate('customer', 'name code');
    }

    const orderObject = order.toObject();

    if (supplierSourceOrder?.attachments?.length) {
      const existingPaths = new Set(
        (orderObject.attachments || [])
          .map((attachment) => attachment?.path)
          .filter(Boolean)
      );

      const inheritedAttachments = supplierSourceOrder.attachments.filter(
        (attachment) => attachment?.path && !existingPaths.has(attachment.path)
      );

      if (inheritedAttachments.length) {
        orderObject.attachments = [
          ...(orderObject.attachments || []),
          ...inheritedAttachments,
        ];
      }
    }

    res.json({
      order: {
        ...orderObject,
        displayInfo: order.getDisplayInfo ? order.getDisplayInfo() : null
      },
      activities,
      relatedOrders
    });
  } catch (error) {
    console.error('Error getting order:', error);
    res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

// ============================================
// 📅 جلب الطلبات القادمة
// ============================================

exports.getUpcomingOrders = async (req, res) => {
  try {
    const now = new Date();

    // ساعتين قبل الوصول
    const twoHoursBefore = new Date(now.getTime() + (2 * 60 * 60 * 1000));

    // جلب الطلبات المحتملة
    const orders = await Order.find({
      status: { $in: ['في انتظار التحميل', 'جاهز للتحميل', 'مخصص للعميل', 'في الطريق'] },
    })
    .populate('customer', 'name code phone email')
    .populate('supplier', 'name company contactPerson')
    .populate('createdBy', 'name email')
    .populate('driver', 'name phone vehicleNumber');

    const upcomingOrders = [];

    for (const order of orders) {
      const arrivalDateTime = order.getFullArrivalDateTime();

      // الطلب داخل نطاق الإشعار (قبل الوصول بساعتين)
      if (arrivalDateTime > now && arrivalDateTime <= twoHoursBefore) {
        upcomingOrders.push({
          ...order.toObject(),
          arrivalDateTime,
          timeRemaining: formatDuration(arrivalDateTime - now)
        });

        // إرسال الإيميل مرة واحدة فقط
        if (!order.arrivalEmailSentAt) {
          try {
            const timeRemainingMs = arrivalDateTime - now;
            const timeRemaining = formatDuration(timeRemainingMs);

            const emails = await getOrderEmails(order);

            if (!emails || emails.length === 0) {
              console.log(`⚠️ No valid emails for arrival reminder - order ${order.orderNumber}`);
            } else {
              await sendEmail({
                to: emails,
                subject: `⏰ تذكير: اقتراب وصول الطلب ${order.orderNumber}`,
                html: EmailTemplates.arrivalReminderTemplate(order, timeRemaining),
              });

            }

            // تحديث وقت الإرسال
            order.arrivalEmailSentAt = new Date();
            await order.save();

            console.log(`📧 Arrival email sent for order ${order.orderNumber}`);
          } catch (emailError) {
            console.error(`❌ Failed to send arrival email for order ${order.orderNumber}:`, emailError.message);
          }
        }
      }
    }

    return res.json(upcomingOrders);
  } catch (error) {
    console.error('Error getting upcoming orders:', error);
    return res.status(500).json({ error: 'حدث خطأ في جلب الطلبات القريبة' });
  }
};

// ============================================
// ⏱️ جلب الطلبات مع المؤقتات
// ============================================

exports.getOrdersWithTimers = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const filter = {};

    if (req.query.status) {
      filter.status = req.query.status;
    }

    if (req.query.orderSource) {
      filter.orderSource = req.query.orderSource;
    }

    if (req.query.supplierName) {
      filter.supplierName = new RegExp(req.query.supplierName, 'i');
    }

    if (req.query.customerName) {
      filter.customerName = new RegExp(req.query.customerName, 'i');
    }

    // جلب الطلبات
    const orders = await Order.find(filter)
      .populate('customer', 'name code email')
      .populate('supplier', 'name company contactPerson')
      .populate('driver', 'name phone vehicleNumber')
      .populate('createdBy', 'name email')
      .sort({ arrivalDate: 1, arrivalTime: 1 })
      .skip(skip)
      .limit(limit);

    const total = await Order.countDocuments(filter);
    const now = new Date();

    const ordersWithTimers = [];

    for (const order of orders) {
      const arrivalDateTime = order.getFullArrivalDateTime();
      const loadingDateTime = order.getFullLoadingDateTime();

      const arrivalRemaining = arrivalDateTime - now;
      const loadingRemaining = loadingDateTime - now;

      const arrivalCountdown = arrivalRemaining > 0 ? formatDuration(arrivalRemaining) : 'تأخر';
      const loadingCountdown = loadingRemaining > 0 ? formatDuration(loadingRemaining) : 'تأخر';

      // قبل الوصول بساعتين ونصف
      const isApproachingArrival = arrivalRemaining > 0 && arrivalRemaining <= 2.5 * 60 * 60 * 1000;
      const isApproachingLoading = loadingRemaining > 0 && loadingRemaining <= 2.5 * 60 * 60 * 1000;

      // إرسال الإيميل (مرة واحدة فقط)
      if (isApproachingArrival && !order.arrivalEmailSentAt) {
        try {
          const emails = await getOrderEmails(order);

          if (!emails || emails.length === 0) {
            console.log(`⚠️ No valid emails for arrival reminder - order ${order.orderNumber}`);
          } else {
            await sendEmail({
              to: emails,
              subject: `⏰ تذكير: اقتراب وصول الطلب ${order.orderNumber}`,
              html: EmailTemplates.arrivalReminderTemplate(order, formatDuration(arrivalRemaining)),
            });
          }

          order.arrivalEmailSentAt = new Date();
          await order.save();

          console.log(`📧 Arrival reminder email sent for order ${order.orderNumber}`);
        } catch (emailError) {
          console.error(`❌ Failed to send arrival email for order ${order.orderNumber}:`, emailError.message);
        }
      }

      ordersWithTimers.push({
        ...order.toObject(),
        displayInfo: order.getDisplayInfo ? order.getDisplayInfo() : null,
        arrivalDateTime,
        loadingDateTime,
        arrivalRemaining,
        loadingRemaining,
        arrivalCountdown,
        loadingCountdown,
        needsArrivalNotification: isApproachingArrival && !order.arrivalEmailSentAt,
        isApproachingArrival,
        isApproachingLoading,
        isArrivalOverdue: arrivalRemaining < 0,
        isLoadingOverdue: loadingRemaining < 0
      });
    }

    return res.json({
      orders: ordersWithTimers,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('Error getting orders with timers:', error);
    return res.status(500).json({ error: 'حدث خطأ في جلب الطلبات' });
  }
};

// ============================================
// 🔔 إرسال تذكير بالوصول
// ============================================

exports.sendArrivalReminder = async (req, res) => {
  try {
    const { orderId } = req.params;

    const order = await Order.findById(orderId)
      .populate('customer', 'name email phone')
      .populate('supplier', 'name email contactPerson')
      .populate('createdBy', 'name email');

    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    const User = require('../models/User');
    const Notification = require('../models/Notification');
    const Activity = require('../models/Activity');

    // المستخدمين المستهدفين (منشئ الطلب + الإداريين + العميل إذا كان له إيميل)
    const usersToNotify = await User.find({
      $or: [
        { _id: order.createdBy?._id },
        { role: { $in: ['admin', 'owner'] } }
      ],
      isActive: true
    });

    if (usersToNotify.length === 0) {
      return res.status(400).json({ error: 'لا يوجد مستخدمون للإشعار' });
    }

    const arrivalDateTime = order.getFullArrivalDateTime();
    const timeRemainingMs = arrivalDateTime - new Date();
    const timeRemaining = formatDuration(timeRemainingMs);

    // إنشاء Notification
    const notification = new Notification({
      type: 'arrival_reminder',
      title: 'تذكير بقرب وقت الوصول',
      message: `الطلب رقم ${order.orderNumber} (${order.customerName}) سيصل خلال ${timeRemaining}`,
      data: {
        orderId: order._id,
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        supplierName: order.supplierName,
        arrivalTime: `${order.arrivalDate.toLocaleDateString('ar-SA')} ${order.arrivalTime}`,
        timeRemaining,
        isManual: true
      },
      recipients: usersToNotify.map(user => ({ user: user._id })),
      createdBy: req.user._id
    });

    await notification.save();

    // إرسال الإيميل
    try {
      const emails = await getOrderEmails(order);

      if (!emails || emails.length === 0) {
        console.log(`⚠️ No valid emails for arrival reminder - order ${order.orderNumber}`);
      } else {
        await sendEmail({
          to: emails,
          subject: `⏰ تذكير بوصول الطلب ${order.orderNumber}`,
          html: EmailTemplates.arrivalReminderTemplate(order, timeRemaining),
        });
      }
    } catch (emailError) {
      console.error(`❌ Failed to send arrival reminder email for order ${order.orderNumber}:`, emailError.message);
    }

    // تحديث حالة الإرسال
    order.arrivalNotificationSentAt = new Date();
    order.arrivalEmailSentAt = new Date();
    await order.save();

    // تسجيل النشاط
    const activity = new Activity({
      orderId: order._id,
      activityType: 'إشعار',
      description: `تم إرسال إشعار وإيميل تذكير قبل الوصول للطلب رقم ${order.orderNumber}`,
      performedBy: req.user._id,
      performedByName: req.user.name,
      changes: {
        'وقت الإشعار': new Date().toLocaleString('ar-SA'),
        'وقت الوصول المتبقي': timeRemaining
      }
    });
    await activity.save();

    return res.json({
      message: 'تم إرسال الإشعار والإيميل بنجاح',
      notification,
      timeRemaining
    });

  } catch (error) {
    console.error('Error sending arrival reminder:', error);
    return res.status(500).json({ error: 'حدث خطأ في إرسال الإشعار' });
  }
};

// ============================================
// ✏️ تحديث الطلب
// ============================================

exports.updateOrder = async (req, res) => {

  console.log('🔥 UPDATE ORDER HIT');
  console.log('BODY:', req.body);
  console.log('FILE:', req.file);
  try {
    upload(req, res, async (err) => {
      if (err) {
        return res.status(400).json({ error: err.message });
      }

      const order = await Order.findById(req.params.id)
        .populate('customer', 'name code phone email city area address')
        .populate('supplier', 'name company contactPerson phone address')
        .populate('driver', 'name phone vehicleNumber');

      if (!order) {
        return res.status(404).json({ error: 'الطلب غير موجود' });
      }

      const previousDriverId = toIdString(order.driver);
      const actingAsSupplierPortal = isSupplierPortalUser(req.user);

      if (!(await ensureSupplierPortalOrderAccess(req.user, order))) {
        return res.status(403).json({ error: 'غير مصرح لك بتعديل هذا الطلب' });
      }

      if (actingAsSupplierPortal) {
        if (order.entryChannel !== 'supplier_portal') {
          return res.status(403).json({ error: 'يمكن تعديل طلبات بوابة الموردين فقط' });
        }

        if (!['pending_review', 'rejected'].includes(normalizePortalStatus(order.portalStatus))) {
          return res.status(400).json({
            error: 'لا يمكن تعديل الطلب بعد اعتماده من الحركة',
          });
        }
      }

      // ============================================
      // 🧠 تحديد نوع الطلب
      // ============================================
      const isCustomerOrder = order.orderSource === 'عميل';
      const isSupplierOrder = order.orderSource === 'مورد';

      // ============================================
      // 🧩 الحقول المسموح تعديلها
      // ============================================
      const baseAllowedUpdates = [
        'customer',
        'driver', 'driverName', 'driverPhone', 'vehicleNumber',
        'notes', 'supplierNotes', 'customerNotes', 'internalNotes',
        'actualArrivalTime', 'loadingDuration', 'delayReason',
        'quantity', 'unit', 'fuelType', 'productType',
        'unitPrice', 'totalPrice', 'paymentMethod', 'paymentStatus',
        'city', 'area', 'address',
        'loadingDate', 'loadingTime', 'arrivalDate', 'arrivalTime',
        'status', 'mergeStatus',
        'requestType',
        'orderDate',
        'portalCustomer',
        'destinationStationId',
        'destinationStationName',
      ];

      const forbiddenForSupplier = ['supplierOrderNumber', 'supplierName'];
      const supplierPortalAllowedUpdates = [
        'supplierOrderNumber',
        'notes',
        'supplierNotes',
        'quantity',
        'unit',
        'fuelType',
        'productType',
        'city',
        'area',
        'address',
        'loadingDate',
        'loadingTime',
        'arrivalDate',
        'arrivalTime',
        'orderDate',
        'portalCustomer',
        'destinationStationId',
        'destinationStationName',
      ];

      const allowedUpdates = actingAsSupplierPortal
        ? supplierPortalAllowedUpdates
        : isSupplierOrder
        ? baseAllowedUpdates.filter(
            (f) => !forbiddenForSupplier.includes(f)
          )
        : baseAllowedUpdates;

      if (isSupplierOrder && 'requestType' in req.body) {
        delete req.body.requestType;
      }

      // حماية إضافية
      forbiddenForSupplier.forEach((field) => delete req.body[field]);

      const updates = {};
      Object.keys(req.body).forEach((key) => {
        if (allowedUpdates.includes(key)) {
          updates[key] = req.body[key] !== undefined ? req.body[key] : null;
        }
      });

      // ============================================
      // 👤 تغيير العميل
      // ============================================
      const oldCustomerId = order.customer?._id?.toString();

      if (updates.customer && updates.customer !== oldCustomerId) {
        const newCustomer = await Customer.findById(updates.customer);
        if (!newCustomer) {
          return res.status(400).json({ error: 'العميل الجديد غير موجود' });
        }

        order.customer = newCustomer._id;
        order.customerName = newCustomer.name;
        order.customerCode = newCustomer.code;
        order.customerPhone = newCustomer.phone;
        order.customerEmail = newCustomer.email ?? null;

        order.city = updates.city ?? newCustomer.city;
        order.area = updates.area ?? newCustomer.area;
        order.address = updates.address ?? newCustomer.address;
      }

      // ============================================
      // 🚚 تغيير السائق
      // ============================================
      if ('driver' in updates) {
        if (updates.driver) {
          const driver = await Driver.findById(updates.driver);
          if (driver) {
            updates.driverName = driver.name;
            updates.driverPhone = driver.phone;
            updates.vehicleNumber = driver.vehicleNumber;
          }
        } else {
          updates.driverName = null;
          updates.driverPhone = null;
          updates.vehicleNumber = null;
        }
      }

      if ('portalCustomer' in updates) {
        if (updates.portalCustomer) {
          const portalCustomer = await Customer.findById(updates.portalCustomer)
            .select('name supplier supplierStationIds');
          if (!portalCustomer) {
            return res.status(400).json({ error: 'الجهة المختارة غير موجودة' });
          }

          const orderSupplierId = toIdString(order.supplier?._id || order.supplier);
          const portalCustomerSupplierId = toIdString(portalCustomer.supplier);
          if (
            orderSupplierId &&
            portalCustomerSupplierId &&
            portalCustomerSupplierId !== orderSupplierId
          ) {
            return res.status(400).json({
              error: 'هذه الجهة غير مرتبطة بالمورد الحالي',
            });
          }

          updates.portalCustomerName = portalCustomer.name;
        } else {
          updates.portalCustomerName = null;
        }
      }

      if ('destinationStationId' in updates) {
        if (updates.destinationStationId) {
          const station = await Station.findById(updates.destinationStationId)
            .select('stationName city location');
          if (!station) {
            return res.status(400).json({ error: 'المحطة المختارة غير موجودة' });
          }

          const targetCustomerId =
            updates.portalCustomer || toIdString(order.portalCustomer?._id || order.portalCustomer);
          if (targetCustomerId) {
            const portalCustomer = await Customer.findById(targetCustomerId)
              .select('supplierStationIds');
            const allowedStations = new Set(
              (portalCustomer?.supplierStationIds || []).map((value) => toIdString(value))
            );
            if (allowedStations.size > 0 && !allowedStations.has(toIdString(station._id))) {
              return res.status(400).json({
                error: 'المحطة المختارة غير مرتبطة بهذه الجهة',
              });
            }
          }

          updates.destinationStationName = station.stationName;
          if (!updates.city) updates.city = station.city || order.city;
          if (!updates.area) updates.area = station.stationName || order.area;
          if (!updates.address) updates.address = station.location || order.address;
        } else {
          updates.destinationStationName = null;
        }
      }

      // ============================================
      // 🔄 تغيير نوع العملية (شراء / نقل)
      // ============================================
      if ('requestType' in updates) {
        order.requestType = updates.requestType;
        if (updates.requestType === 'شراء') {
          order.driver = null;
          order.driverName = null;
          order.driverPhone = null;
          order.vehicleNumber = null;
        }
      }

      // ============================================
      // 📍 تحديث موقع العميل
      // ============================================
      if (
        ('city' in updates || 'area' in updates || 'address' in updates) &&
        order.customer
      ) {
        await Customer.findByIdAndUpdate(order.customer._id, {
          city: updates.city ?? order.customer.city,
          area: updates.area ?? order.customer.area,
          address: updates.address ?? order.customer.address,
        });
      }

      // ============================================
      // 📅 التواريخ
      // ============================================
      if (updates.loadingDate) updates.loadingDate = new Date(updates.loadingDate);
      if (updates.arrivalDate) updates.arrivalDate = new Date(updates.arrivalDate);
      if (updates.orderDate) updates.orderDate = new Date(updates.orderDate);

      // ============================================
      // 📎 الملفات
      // ============================================
      const remoteAttachments = parseRemoteAttachments(
        req.body.attachmentUrls,
        req.user,
        'order-attachment'
      );
      const localAttachments = (req.files?.attachments || []).map((file) => ({
        filename: file.originalname,
        path: file.path,
        uploadedAt: new Date(),
        uploadedBy: req.user._id,
      }));

      if (remoteAttachments.length || localAttachments.length) {
        updates.attachments = [
          ...order.attachments,
          ...remoteAttachments,
          ...localAttachments,
        ];
      }

      // ============================================
      // 🧾 حفظ القيم القديمة
      // ============================================
      const oldData = { ...order.toObject() };

      // ============================================
      // 💾 حفظ الطلب
      // ============================================
      Object.assign(order, updates);
      order.updatedAt = new Date();
      await order.save();

      // ============================================
      // 📝 حساب التغييرات
      // ============================================
      const changes = {};
      const excluded = ['attachments', 'updatedAt'];

      Object.keys(updates).forEach((key) => {
        if (!excluded.includes(key)) {
          if (JSON.stringify(oldData[key]) !== JSON.stringify(order[key])) {
            changes[key] = `من: ${oldData[key] ?? 'غير محدد'} → إلى: ${order[key] ?? 'غير محدد'}`;
          }
        }
      });

      // ============================================
      // 📋 Activity
      // ============================================
      if (Object.keys(changes).length) {
        await Activity.create({
          orderId: order._id,
          activityType: 'تعديل',
          description: `تم تعديل الطلب رقم ${order.orderNumber}`,
          performedBy: req.user._id,
          performedByName: req.user.name,
          changes,
        });
      }

      // ============================================
      // 📧 إرسال الإيميل
      // ============================================
      if (Object.keys(changes).length && order.customerEmail) {
        await sendEmail({
          to: order.customerEmail,
          subject: `تم تعديل طلبك رقم ${order.orderNumber}`,
          html: `
            <h3>مرحبًا ${order.customerName}</h3>
            <p>تم تعديل طلبك، وهذه أهم التغييرات:</p>
            <ul>
              ${Object.values(changes).map(c => `<li>${c}</li>`).join('')}
            </ul>
            <p>شكراً لتعاملكم معنا</p>
          `,
        });
      }

      // ============================================
      // 📤 الرد
      // ============================================
      const populatedOrder = await Order.findById(order._id)
        .populate('customer', 'name code phone email city area address')
        .populate('supplier', 'name company contactPerson phone address')
        .populate('driver', 'name phone vehicleNumber')
        .populate('createdBy', 'name email')
        .populate('portalCustomer', 'name code')
        .populate('destinationStationId', 'stationName stationCode city');

      const currentDriverId = toIdString(populatedOrder?.driver);
      if (currentDriverId && currentDriverId !== previousDriverId) {
        await sendDriverAssignmentNotification({ order: populatedOrder, actor: req.user });
      }

      if (Object.keys(changes).length && actingAsSupplierPortal) {
        await notifySupplierPortal({
          order: populatedOrder,
          actor: req.user,
          title: 'تحديث من المورد على طلب قيد المراجعة',
          message: `قام المورد ${req.user.name} بتحديث الطلب ${order.orderNumber}`,
          type: 'order_updated',
          includeReviewRoles: true,
          extraData: {
            changeCount: Object.keys(changes).length,
          },
        });
      }

      return res.json({
        message: 'تم تحديث الطلب بنجاح',
        order: populatedOrder,
        changes: Object.keys(changes).length ? changes : null,
      });
    });
  } catch (error) {
    console.error('Error updating order:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};


// ============================================
// 🔄 تحديث حالة الطلب
// ============================================

exports.submitDriverLoadingData = async (req, res) => {
  try {
    const { id } = req.params;
    const { actualFuelType, actualLoadedLiters, notes, stationName, attachments } = req.body;

    const order = await Order.findById(id)
      .populate('customer', 'name email phone')
      .populate('supplier', 'name email contactPerson phone')
      .populate('createdBy', 'name email')
      .populate('driver', 'name phone vehicleNumber');

    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    const user = req.user;
    if (!(user?.role === 'driver' || userRequiresAssignedOrdersOnly(user))) {
      return res.status(403).json({
        error: 'هذه العملية متاحة فقط للسائق المخصص للطلب',
      });
    }

    const canAccessOrder = await userCanAccessOrder(user, order);
    if (!canAccessOrder) {
      return res.status(403).json({
        error: 'أنت لست السائق المسؤول عن هذا الطلب',
      });
    }



    if (['تم التسليم', 'تم التنفيذ', 'مكتمل', 'ملغى'].includes(order.status)) {
      return res.status(400).json({
        error: 'لا يمكن تعديل بيانات التعبئة بعد إغلاق الطلب',
      });
    }

    if (!['جاهز للتحميل', 'في انتظار التحميل', 'تم التحميل'].includes(order.status)) {
      return res.status(400).json({
        error: 'يمكن إرسال بيانات التعبئة فقط أثناء مرحلة التحميل',
      });
    }

    const normalizedFuelType = String(actualFuelType || '').trim();
    const loadedLiters = Number(actualLoadedLiters);
    const normalizedNotes = String(notes || '').trim();
    const normalizedStationName = String(
      stationName || order.loadingStationName || order.supplierName || 'محطة أرامكو'
    ).trim();

    if (!normalizedFuelType) {
      return res.status(400).json({
        error: 'نوع الوقود الفعلي مطلوب',
      });
    }

    if (!Number.isFinite(loadedLiters) || loadedLiters <= 0) {
      return res.status(400).json({
        error: 'عدد اللترات الفعلية يجب أن يكون أكبر من صفر',
      });
    }

    order.actualFuelType = normalizedFuelType;
    order.actualLoadedLiters = loadedLiters;
    order.loadingStationName = normalizedStationName;
    order.driverLoadingNotes = normalizedNotes || undefined;
    order.driverLoadingSubmittedAt = new Date();
    order.loadingCompletedAt = new Date();
    order.status = 'تم التحميل';
    order.updatedAt = new Date();

    const normalizedAttachments = Array.isArray(attachments) ? attachments : [];
    const driverUploadedAttachments = [];
    if (normalizedAttachments.length) {
      const uploadedAt = new Date();
      for (const item of normalizedAttachments) {
        if (!item || typeof item !== 'object') continue;
        const filename = String(item.filename || item.name || '').trim();
        const path = String(item.path || item.url || item.downloadUrl || item.downloadURL || '').trim();
        if (!filename || !path) continue;
        driverUploadedAttachments.push({
          filename,
          path,
          uploadedAt,
          uploadedBy: user?._id || null,
        });
      }
    }

    if (!driverUploadedAttachments.length) {
      return res.status(400).json({
        error: 'صورة كرت أرامكو مطلوبة قبل حفظ بيانات التعبئة',
      });
    }

    if (driverUploadedAttachments.length) {
      order.attachments = Array.isArray(order.attachments) ? order.attachments : [];
      order.attachments.push(...driverUploadedAttachments);
    }

    await order.save();

    const updatedOrder = await Order.findById(order._id)
      .populate('customer', 'name email phone')
      .populate('supplier', 'name email contactPerson phone')
      .populate('createdBy', 'name email')
      .populate('driver', 'name phone vehicleNumber');

    await Activity.create({
      orderId: order._id,
      activityType: 'تعديل',
      description: `أرسل السائق بيانات التعبئة الفعلية للطلب ${order.orderNumber}`,
      performedBy: user._id,
      performedByName: user.name || user.email || 'السائق',
      changes: {
        'الوقود الفعلي': normalizedFuelType,
        'اللترات الفعلية': `${loadedLiters} لتر`,
        'محطة التعبئة': normalizedStationName,
        ...(normalizedNotes ? { 'ملاحظات السائق': normalizedNotes } : {}),
        ...(driverUploadedAttachments.length
          ? { 'مرفقات السائق': `${driverUploadedAttachments.length} ملف` }
          : {}),
      },
    });

    try {
      await sendOwnerDriverLoadingNotification({
        order: updatedOrder || order,
        actor: user,
      });
    } catch (notificationError) {
      console.error('Failed to notify owners about driver loading data:', notificationError.message);
    }

    return res.json({
      success: true,
      message: 'تم حفظ بيانات التعبئة بنجاح',
      order: updatedOrder || order,
    });
  } catch (error) {
    console.error('submitDriverLoadingData error:', error);
    return res.status(500).json({
      error: 'حدث خطأ أثناء حفظ بيانات التعبئة',
    });
  }
};

exports.reviewSupplierPortalOrder = async (req, res) => {
  try {
    if (!isSupplierPortalReviewUser(req.user)) {
      return res.status(403).json({
        success: false,
        error: 'غير مصرح لك بمراجعة طلبات الموردين',
      });
    }

    const {
      decision,
      note,
      destinationStationId,
      driverId,
      portalCustomer,
    } = req.body || {};

    const order = await Order.findById(req.params.id)
      .populate('supplier', 'name company contactPerson phone email')
      .populate('driver', 'name phone vehicleNumber')
      .populate('portalCustomer', 'name code supplier supplierStationIds')
      .populate('destinationStationId', 'stationName stationCode city location');

    if (!order) {
      return res.status(404).json({
        success: false,
        error: 'الطلب غير موجود',
      });
    }

    if (order.entryChannel !== 'supplier_portal') {
      return res.status(400).json({
        success: false,
        error: 'هذا الطلب ليس من بوابة الموردين',
      });
    }

    const oldDriverId = toIdString(order.driver?._id || order.driver);
    const changes = {};
    const normalizedDecision =
      decision == null || String(decision).trim().isEmpty
        ? null
        : normalizePortalStatus(decision);

    if (portalCustomer !== undefined) {
      if (portalCustomer) {
        const portalCustomerDoc = await Customer.findById(portalCustomer)
          .select('name supplier supplierStationIds');
        if (!portalCustomerDoc) {
          return res.status(400).json({
            success: false,
            error: 'الجهة المختارة غير موجودة',
          });
        }

        const orderSupplierId = toIdString(order.supplier?._id || order.supplier);
        const portalCustomerSupplierId = toIdString(portalCustomerDoc.supplier);
        if (
          orderSupplierId &&
          portalCustomerSupplierId &&
          orderSupplierId !== portalCustomerSupplierId
        ) {
          return res.status(400).json({
            success: false,
            error: 'هذه الجهة غير مرتبطة بالمورد الحالي',
          });
        }

        order.portalCustomer = portalCustomerDoc._id;
        order.portalCustomerName = portalCustomerDoc.name || '';
        changes['الجهة'] = order.portalCustomerName;
      } else {
        order.portalCustomer = null;
        order.portalCustomerName = '';
        changes['الجهة'] = 'تمت الإزالة';
      }
    }

    if (destinationStationId !== undefined) {
      if (destinationStationId) {
        const station = await Station.findById(destinationStationId)
          .select('stationName stationCode city location');
        if (!station) {
          return res.status(400).json({
            success: false,
            error: 'المحطة المختارة غير موجودة',
          });
        }

        const targetCustomerId = toIdString(order.portalCustomer?._id || order.portalCustomer);
        if (targetCustomerId) {
          const portalCustomerDoc = await Customer.findById(targetCustomerId)
            .select('supplierStationIds');
          const allowedStations = new Set(
            (portalCustomerDoc?.supplierStationIds || []).map((value) => toIdString(value))
          );
          if (allowedStations.size > 0 && !allowedStations.has(toIdString(station._id))) {
            return res.status(400).json({
              success: false,
              error: 'المحطة المختارة غير مرتبطة بهذه الجهة',
            });
          }
        }

        order.destinationStationId = station._id;
        order.destinationStationName = station.stationName || '';
        order.city = station.city || order.city;
        order.area = station.stationName || order.area;
        order.address = station.location || order.address;
        changes['محطة التفريغ'] = order.destinationStationName;
      } else {
        order.destinationStationId = null;
        order.destinationStationName = '';
        changes['محطة التفريغ'] = 'تمت الإزالة';
      }
    }

    if (driverId !== undefined) {
      if (driverId) {
        const driver = await Driver.findById(driverId);
        if (!driver) {
          return res.status(400).json({
            success: false,
            error: 'السائق المختار غير موجود',
          });
        }

        order.driver = driver._id;
        order.driverName = driver.name;
        order.driverPhone = driver.phone;
        order.vehicleNumber = driver.vehicleNumber;
        changes['السائق'] = driver.name;
      } else {
        order.driver = null;
        order.driverName = '';
        order.driverPhone = '';
        order.vehicleNumber = '';
        changes['السائق'] = 'تمت الإزالة';
      }
    }

    if (normalizedDecision) {
      order.portalStatus = normalizedDecision;
      order.portalReviewedAt = new Date();
      order.portalReviewedBy = req.user._id;
      order.portalReviewedByName = req.user.name;
      order.portalReviewNotes = String(note || '').trim() || null;
      changes['حالة المراجعة'] =
        normalizedDecision === 'approved' ? 'تمت الموافقة' : 'تم الرفض';

      if (normalizedDecision === 'approved' && !order.status) {
        order.status = 'تم الإنشاء';
      }
    } else if (note !== undefined) {
      order.portalReviewNotes = String(note || '').trim() || null;
      changes['ملاحظات الحركة'] = order.portalReviewNotes || 'تم المسح';
    }

    if (order.portalStatus === 'approved' && toIdString(order.driver)) {
      order.status = 'جاهز للتحميل';
    }

    order.updatedAt = new Date();
    await order.save();

    const populatedOrder = await Order.findById(order._id)
      .populate('supplier', 'name company contactPerson phone email')
      .populate('createdBy', 'name email')
      .populate('driver', 'name phone vehicleNumber')
      .populate('portalCustomer', 'name code')
      .populate('destinationStationId', 'stationName stationCode city');

    await Activity.create({
      orderId: order._id,
      activityType: normalizedDecision ? 'تعديل' : 'إضافة ملاحظة',
      description: normalizedDecision === 'approved'
        ? `تمت الموافقة على طلب المورد ${order.orderNumber}`
        : normalizedDecision === 'rejected'
        ? `تم رفض طلب المورد ${order.orderNumber}`
        : `تم تحديث بيانات طلب المورد ${order.orderNumber}`,
      performedBy: req.user._id,
      performedByName: req.user.name,
      changes,
    });

    if (toIdString(populatedOrder?.driver) && toIdString(populatedOrder?.driver) !== oldDriverId) {
      await sendDriverAssignmentNotification({ order: populatedOrder, actor: req.user });
    }

    await notifySupplierPortal({
      order: populatedOrder,
      actor: req.user,
      title: normalizedDecision === 'approved'
        ? 'تمت الموافقة على طلبك'
        : normalizedDecision === 'rejected'
        ? 'تم رفض طلبك'
        : 'تم تحديث طلبك',
      message: normalizedDecision === 'approved'
        ? `وافقت الحركة على الطلب ${order.orderNumber}${order.destinationStationName ? ` لمحطة ${order.destinationStationName}` : ''}`
        : normalizedDecision === 'rejected'
        ? `تم رفض الطلب ${order.orderNumber}${order.portalReviewNotes ? ` - ${order.portalReviewNotes}` : ''}`
        : `تم تحديث بيانات الطلب ${order.orderNumber}`,
      type: 'status_changed',
      includeSupplierUsers: true,
      extraData: {
        reviewNotes: order.portalReviewNotes || '',
      },
    });

    return res.json({
      success: true,
      message: normalizedDecision === 'approved'
        ? 'تمت الموافقة على الطلب'
        : normalizedDecision === 'rejected'
        ? 'تم رفض الطلب'
        : 'تم تحديث الطلب',
      order: populatedOrder,
    });
  } catch (error) {
    console.error('reviewSupplierPortalOrder error:', error);
    return res.status(500).json({
      success: false,
      error: 'حدث خطأ أثناء مراجعة طلب المورد',
    });
  }
};

exports.updateOrderStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, reason, attachments } = req.body;

    const order = await Order.findById(id)
      .populate('customer', 'name email phone')
      .populate('supplier', 'name email contactPerson phone')
      .populate('createdBy', 'name email')
      .populate('driver', 'name phone vehicleNumber');

    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    const oldStatus = order.status;

    const isSystemAuto =
      req.headers['x-system-auto'] === 'true' ||
      req.user?.role === 'system';

    if (
      isSystemAuto &&
      order.orderSource === 'مدمج' &&
      status === 'تم التنفيذ'
    ) {
      order.status = 'تم التنفيذ';
      order.mergeStatus = 'مكتمل';
      order.completedAt = new Date();
      order.updatedAt = new Date();

      await order.save();

      const activity = new Activity({
        orderId: order._id,
        activityType: 'تغيير حالة',
        description: `تم تنفيذ الطلب ${order.orderNumber} تلقائيًا بواسطة النظام`,
        performedBy: null,
        performedByName: 'النظام',
        changes: {
          الحالة: `من: ${oldStatus} → إلى: تم التنفيذ`,
        },
      });
      await activity.save();

      try {
        await ownerOrderNotificationService.notifyOwnerOnMergedOrderCompletion({
          order,
          oldStatus,
          reason,
          trigger: 'auto_status_update',
          completedBy: 'النظام',
        });
      } catch (ownerNotifyError) {
        console.error('❌ Failed owner completion notification (auto status):', ownerNotifyError.message);
      }

      return res.json({
        success: true,
        message: 'تم تنفيذ الطلب المدمج تلقائيًا',
        data: {
          order,
          oldStatus,
          newStatus: 'تم التنفيذ',
          auto: true,
        },
      });
    }

    // التحقق من أن الحالة لم تتغير
    if (oldStatus === status) {
      return res.json({
        message: 'الحالة لم تتغير',
        order,
      });
    }

    // ============================================
    // 🔐 التحقق من الصلاحيات
    // ============================================
    const user = req.user;
    const canManageOrderStatus = ['admin', 'owner', 'manager'].includes(user.role);

    if (!canManageOrderStatus) {
      if (user.role === 'driver' || userRequiresAssignedOrdersOnly(user)) {
        const allowedDriverStatuses = ['في الطريق', 'تم التسليم', 'تم التحميل'];
        if (!allowedDriverStatuses.includes(status)) {
          return res.status(403).json({
            error: 'غير مصرح للسائق بتغيير الحالة إلى هذا الوضع',
          });
        }

        const canAccessOrder = await userCanAccessOrder(user, order);
        if (!canAccessOrder) {
          return res.status(403).json({
            error: 'أنت لست السائق المسؤول عن هذا الطلب',
          });
        }

        if (
          status === 'تم التحميل' &&
          (!String(order.actualFuelType || '').trim() || !(Number(order.actualLoadedLiters) > 0))
        ) {
          return res.status(400).json({
            error: 'يجب على السائق إرسال بيانات التعبئة الفعلية قبل اعتماد حالة تم التحميل',
          });
        }
      } else {
        return res.status(403).json({
          error: 'غير مصرح لك بتغيير حالة الطلب',
        });
      }
    }

    if (
      (user.role === 'driver' || userRequiresAssignedOrdersOnly(user)) &&
      status === 'في الطريق' &&
      order.entryChannel === 'movement' &&
      order.orderSource === 'مورد' &&
      order.movementState === 'pending_dispatch'
    ) {
      return res.status(400).json({
        error: 'الطلب بانتظار توجيه الحركة إلى العميل قبل بدء التوصيل.',
      });
    }

    // ============================================
    // 🔄 التحقق من التسلسل المنطقي للحالات
    // ============================================
    const statusFlow = {
      // ========== طلبات المورد ==========
      'في المستودع': ['تم الإنشاء', 'ملغى'],
      'تم الإنشاء': ['في انتظار الدمج', 'ملغى'],
      'في انتظار الدمج': ['تم دمجه مع العميل', 'ملغى'],
      'تم دمجه مع العميل': ['جاهز للتحميل', 'ملغى'],
      'جاهز للتحميل': ['تم التحميل', 'ملغى'],
      'تم التحميل': ['في الطريق', 'ملغى'],
      'في الطريق': ['تم التسليم', 'ملغى'],
      'تم التسليم': ['مكتمل'],
      
      // ========== طلبات العميل ==========
      'في انتظار التخصيص': ['تم تخصيص طلب المورد', 'ملغى'],
      'تم تخصيص طلب المورد': ['في انتظار الدمج', 'ملغى'],
      'في انتظار الدمج': ['تم دمجه مع المورد', 'ملغى'],
      'تم دمجه مع المورد': ['في انتظار التحميل', 'ملغى'],
      'في انتظار التحميل': ['في الطريق', 'ملغى'],
      'في الطريق': ['تم التسليم', 'ملغى'],
      'تم التسليم': ['مكتمل'],
      
      // ========== طلبات مدمجة ==========
      'تم الدمج': ['مخصص للعميل', 'ملغى'],
      'مخصص للعميل': ['جاهز للتحميل', 'ملغى'],
      'جاهز للتحميل': ['تم التحميل', 'ملغى'],
      'تم التحميل': ['في الطريق', 'ملغى'],
      'في الطريق': ['تم التسليم', 'ملغى'],
      'تم التسليم': ['تم التنفيذ', 'ملغى'],
'تم التنفيذ': ['مكتمل'],
    };

    // التحقق من أن الانتقال مسموح
    if (!statusFlow[oldStatus] || !statusFlow[oldStatus].includes(status)) {
      return res.status(400).json({
        error: `غير مسموح بتغيير الحالة من "${oldStatus}" إلى "${status}"`,
        allowedStatuses: statusFlow[oldStatus] || []
      });
    }

    const normalizedAttachments = Array.isArray(attachments) ? attachments : [];
    const uploadedAttachments = [];
    if (normalizedAttachments.length) {
      const uploadedAt = new Date();
      for (const item of normalizedAttachments) {
        if (!item) continue;

        if (typeof item === 'string') {
          const path = item.trim();
          if (!path) continue;
          const normalizedPath = path.replaceAll('\\', '/');
          const filename =
            normalizedPath.split('/').pop()?.trim() || 'attachment';
          uploadedAttachments.push({
            filename,
            path,
            uploadedAt,
            uploadedBy: user?._id || null,
          });
          continue;
        }

        if (typeof item !== 'object') continue;

        const filename = String(item.filename || item.name || '').trim();
        const path = String(
          item.path ||
            item.url ||
            item.downloadUrl ||
            item.downloadURL ||
            item.fileUrl ||
            '',
        ).trim();
        if (!filename || !path) continue;
        uploadedAttachments.push({
          filename,
          path,
          uploadedAt,
          uploadedBy: user?._id || null,
        });
      }
    }

    const isDriverActor =
      user?.role === 'driver' || userRequiresAssignedOrdersOnly(user);

    if (isDriverActor && status === 'تم التسليم' && uploadedAttachments.length < 6) {
      return res.status(400).json({
        error: 'يجب إرفاق 6 صور (5 صور + سند الاستلام) قبل اعتماد حالة تم التسليم',
      });
    }

    // ============================================
    // 📝 تحديث الحالة ومعالجة الحالات الخاصة
    // ============================================
    order.status = status;
    order.updatedAt = new Date();

    switch(status) {
      case 'تم التحميل':
        order.loadingCompletedAt = new Date();
        if (order.driver) {
          try {
            // تحديث إحصائيات السائق
            await mongoose.model('Driver').findByIdAndUpdate(
              order.driver._id,
              {
                $inc: {
                  totalDeliveries: 1,
                  totalEarnings: order.driverEarnings || 0,
                  totalDistance: order.distance || 0
                }
              }
            );
          } catch (statsError) {
            console.error('❌ Error updating driver stats:', statsError);
          }
        }
        break;
        
      case 'في الطريق':
        // بدء التتبع
        order.trackingStartedAt = new Date();
        break;
        
      case 'تم التسليم':
        order.completedAt = new Date();
        order.actualArrivalTime = new Date().toLocaleTimeString('ar-SA', { 
          hour: '2-digit', 
          minute: '2-digit' 
        });
        break;
        
      case 'تم التنفيذ':
        order.completedAt = new Date();
        break;
        
      case 'ملغى':
        order.cancelledAt = new Date();
        if (reason) {
          order.cancellationReason = reason;
          order.notes = (order.notes || '') + `\nسبب الإلغاء: ${reason}`;
        }
        break;
        
      case 'مكتمل':
        order.completedAt = new Date();
        order.mergeStatus = 'مكتمل';
        break;
    }

    // ============================================
    // 💾 حفظ التغييرات
    // ============================================
    if (uploadedAttachments.length) {
      order.attachments = Array.isArray(order.attachments) ? order.attachments : [];
      order.attachments.push(...uploadedAttachments);
    }

    await order.save();

    if (status === 'تم التنفيذ' && order.orderSource === 'مدمج') {
      try {
        await ownerOrderNotificationService.notifyOwnerOnMergedOrderCompletion({
          order,
          oldStatus,
          reason,
          trigger: 'manual_status_update',
          completedBy: user.name || user.email || 'النظام',
        });
      } catch (ownerNotifyError) {
        console.error('❌ Failed owner completion notification (manual status):', ownerNotifyError.message);
      }
    }

    // ============================================
    // 📋 تسجيل النشاط
    // ============================================
    const activity = new Activity({
      orderId: order._id,
      activityType: 'تغيير حالة',
      description: `تم تغيير حالة الطلب رقم ${order.orderNumber} من "${oldStatus}" إلى "${status}"`,
      performedBy: user._id,
      performedByName: user.name,
      changes: {
        الحالة: `من: ${oldStatus} → إلى: ${status}`,
        ...(reason ? { 'سبب التغيير': reason } : {}),
        ...(status === 'تم التحميل' ? { 'وقت التحميل الفعلي': new Date().toLocaleString('ar-SA') } : {}),
        ...(status === 'تم التسليم' ? { 'وقت التسليم الفعلي': new Date().toLocaleString('ar-SA') } : {}),
        ...(uploadedAttachments.length
          ? { 'مرفقات مضافة': `${uploadedAttachments.length} ملف` }
          : {}),
      },
    });
    await activity.save();

    // ============================================
    // 📧 إرسال الإيميلات
    // ============================================
    try {
      const emails = await getOrderEmails(order);

      if (!emails || emails.length === 0) {
        console.log(`⚠️ No valid emails for order status update - order ${order.orderNumber}`);
      } else {
        // تحديد قالب الإيميل المناسب
        let emailTemplate;
        
        if (status === 'تم دمجه مع العميل' || status === 'تم تخصيص طلب المورد') {
          // إيميل خاص بالدمج
          const partnerInfo = await order.getMergePartnerInfo();
          if (partnerInfo) {
            if (order.orderSource === 'مورد') {
              emailTemplate = EmailTemplates.mergeSupplierTemplate(order, partnerInfo);
            } else {
              emailTemplate = EmailTemplates.mergeCustomerTemplate(order, partnerInfo);
            }
          } else {
            emailTemplate = EmailTemplates.orderStatusTemplate(order, oldStatus, status, user.name, reason);
          }
        } else {
          // إيميل حالة عادي
          emailTemplate = EmailTemplates.orderStatusTemplate(order, oldStatus, status, user.name, reason);
        }

        await sendEmail({
          to: emails,
          subject: `🔄 تحديث حالة الطلب ${order.orderNumber}`,
          html: emailTemplate,
        });
        
        console.log(`📧 Status update email sent for order ${order.orderNumber}`);
      }
    } catch (emailError) {
      console.error('❌ Failed to send order status email:', emailError.message);
    }

    // ============================================
    // 🔔 إرسال إشعارات إذا لزم الأمر
    // ============================================
    if (['في الطريق', 'تم التسليم', 'تم التحميل'].includes(status)) {
      try {
        const users = await User.find({
          role: { $in: ['movement', 'owner', 'admin'] },
          isBlocked: { $ne: true },
        }).select('_id').lean();

        const recipientsSet = new Set(
          users.map((u) => toIdString(u?._id)).filter(Boolean),
        );

        const createdById = toIdString(order.createdBy?._id || order.createdBy);
        if (createdById) {
          recipientsSet.add(createdById);
        }

        const recipients = [...recipientsSet].filter(Boolean);
        if (recipients.length) {
          const actorName =
            String(user?.name || user?.email || '').trim() || 'المستخدم';
          const title = `تحديث حالة الطلب ${order.orderNumber}`.trim();
          const customerLabel = String(
            order.movementCustomerName || order.customerName || '',
          ).trim();

          const messageParts = [
            `تم تحديث حالة الطلب ${order.orderNumber} إلى "${status}"`,
            actorName ? `بواسطة: ${actorName}` : '',
            order.driverName ? `السائق: ${order.driverName}` : '',
            customerLabel ? `العميل: ${customerLabel}` : '',
            uploadedAttachments.length
              ? `مرفقات جديدة: ${uploadedAttachments.length}`
              : '',
          ].filter(Boolean);

          await NotificationService.send({
            type: 'order_status_update',
            title,
            message: messageParts.join(' • '),
            data: {
              event: 'order_status_update',
              orderId: String(order._id || ''),
              orderNumber: order.orderNumber || '',
              oldStatus,
              newStatus: status,
              updatedBy: actorName,
              updatedByRole: user?.role || '',
              attachmentsAdded: uploadedAttachments.length,
              driverId: toIdString(order.driver?._id || order.driver) || '',
              driverName: order.driverName || '',
              customerName: order.customerName || '',
              movementCustomerName: order.movementCustomerName || '',
              supplierName: order.supplierName || '',
            },
            recipients,
            priority: isDriverActor ? 'high' : 'medium',
            createdBy: user?._id,
            orderId: order?._id,
            channels: ['in_app', 'push', 'email'],
          });
        }
      } catch (notifError) {
        console.error('❌ Failed to send order status notification:', notifError.message);
      }
    }

    // ============================================
    // 📦 تحديث الطلب المدمج المرتبط إذا وجد
    // ============================================
    if (order.mergedWithOrderId && ['تم التسليم', 'تم التحميل', 'في الطريق'].includes(status)) {
      try {
        const mergedOrder = await Order.findById(order.mergedWithOrderId);
        if (mergedOrder) {
          // تحديث حالة الطلب المدمج بناءً على حالة الطلب الحالي
          if (status === 'تم التسليم' && mergedOrder.status !== 'تم التسليم') {
            mergedOrder.status = 'تم التسليم';
            mergedOrder.completedAt = new Date();
            await mergedOrder.save();
            
            // تسجيل نشاط في الطلب المدمج
            const mergedActivity = new Activity({
              orderId: mergedOrder._id,
              activityType: 'تغيير حالة',
              description: `تم تحديث حالة الطلب المدمج تلقائياً إلى "تم التسليم" بناءً على حالة الطلب ${order.orderNumber}`,
              performedBy: user._id,
              performedByName: user.name
            });
            await mergedActivity.save();
          }
        }
      } catch (mergeError) {
        console.error('❌ Error updating merged order:', mergeError.message);
      }
    }

    // ============================================
    // 📊 إرجاع النتيجة
    // ============================================
    const updatedOrder = await Order.findById(order._id)
      .populate('customer', 'name code phone email')
      .populate('supplier', 'name company contactPerson phone')
      .populate('driver', 'name phone vehicleNumber')
      .populate('createdBy', 'name email');

    return res.json({
      success: true,
      message: 'تم تحديث حالة الطلب بنجاح',
      data: {
        order: {
          ...updatedOrder.toObject(),
          displayInfo: updatedOrder.getDisplayInfo ? updatedOrder.getDisplayInfo() : null
        },
        oldStatus,
        newStatus: status,
        updatedBy: {
          id: user._id,
          name: user.name,
          role: user.role
        },
        timestamp: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('❌ Error updating order status:', error);
    return res.status(500).json({ 
      error: 'حدث خطأ في السيرفر',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};
// // ============================================
// // 🔗 دمج الطلبات - محدثة حسب المتطلبات
// // ============================================

// exports.mergeOrders = async (req, res) => {
//   const session = await mongoose.startSession();
//   session.startTransaction();
  
//   try {
//     const { supplierOrderId, customerOrderId } = req.body;

//     // =========================
//     // 1️⃣ التحقق من المدخلات
//     // =========================
//     if (!supplierOrderId || !customerOrderId) {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'معرف طلب المورد ومعرف طلب العميل مطلوبان',
//       });
//     }

//     if (supplierOrderId === customerOrderId) {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'لا يمكن دمج الطلب مع نفسه',
//       });
//     }

//     // =========================
//     // 2️⃣ جلب الطلبات مع session
//     // =========================
//     const supplierOrder = await Order.findById(supplierOrderId).session(session);
//     const customerOrder = await Order.findById(customerOrderId).session(session);

//     if (!supplierOrder || !customerOrder) {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(404).json({
//         success: false,
//         message: 'أحد الطلبات غير موجود',
//       });
//     }

//     // =========================
//     // 3️⃣ التحقق من أنواع الطلبات
//     // =========================
//     if (supplierOrder.orderSource !== 'مورد') {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'الطلب الأول يجب أن يكون طلب مورد',
//       });
//     }

//     if (customerOrder.orderSource !== 'عميل') {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'الطلب الثاني يجب أن يكون طلب عميل',
//       });
//     }

//     // =========================
//     // 4️⃣ التحقق من حالة الدمج
//     // =========================
//     if (supplierOrder.mergeStatus !== 'منفصل' || customerOrder.mergeStatus !== 'منفصل') {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'أحد الطلبات تم دمجه مسبقًا',
//       });
//     }

//     // =========================
//     // 5️⃣ التحقق من التوافق
//     // =========================
//     if (supplierOrder.fuelType !== customerOrder.fuelType) {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'نوع الوقود غير متطابق',
//       });
//     }

//     const supplierQty = Number(supplierOrder.quantity || 0);
//     const customerQty = Number(customerOrder.quantity || 0);

//     if (supplierQty < customerQty) {
//       await session.abortTransaction();
//       session.endSession();
      
//       return res.status(400).json({
//         success: false,
//         message: 'كمية المورد أقل من كمية طلب العميل',
//       });
//     }

//     // =========================
//     // 6️⃣ إنشاء رقم الطلب المدموج
//     // =========================
//     const today = new Date();
//     const y = today.getFullYear();
//     const m = String(today.getMonth() + 1).padStart(2, '0');
//     const d = String(today.getDate()).padStart(2, '0');
//     const rand = Math.floor(1000 + Math.random() * 9000);
//     const mergedOrderNumber = `MIX-${y}${m}${d}-${rand}`;

//     // =========================
//     // 7️⃣ تحديد الموقع
//     // =========================
//     let city, area, address;

//     if (customerOrder.city && customerOrder.area) {
//       city = customerOrder.city;
//       area = customerOrder.area;
//       address = customerOrder.address || `${city} - ${area}`;
//     } else if (supplierOrder.city && supplierOrder.area) {
//       city = supplierOrder.city;
//       area = supplierOrder.area;
//       address = supplierOrder.address || `${city} - ${area}`;
//     } else {
//       city = 'غير محدد';
//       area = 'غير محدد';
//       address = 'غير محدد';
//     }

//     // =========================
//     // 8️⃣ إنشاء الطلب المدموج
//     // =========================
//     const mergedOrderData = {
//       orderSource: 'مدمج',
//       mergeStatus: 'مدمج',
//       orderNumber: mergedOrderNumber,
      
//       // معلومات الدمج
//       mergedWithOrderId: null,
//       mergedWithInfo: {
//         supplierOrderNumber: supplierOrder.orderNumber,
//         customerOrderNumber: customerOrder.orderNumber,
//         supplierName: supplierOrder.supplierName,
//         customerName: customerOrder.customerName,
//         mergedAt: new Date()
//       },
      
//       // معلومات المورد
//       supplierOrderNumber: supplierOrder.supplierOrderNumber,
//       supplier: supplierOrder.supplier,
//       supplierName: supplierOrder.supplierName,
//       supplierPhone: supplierOrder.supplierPhone,
//       supplierCompany: supplierOrder.supplierCompany,
//       supplierContactPerson: supplierOrder.supplierContactPerson,
//       supplierAddress: supplierOrder.supplierAddress,
      
//       // معلومات العميل
//       customer: customerOrder.customer,
//       customerName: customerOrder.customerName,
//       customerCode: customerOrder.customerCode,
//       customerPhone: customerOrder.customerPhone,
//       customerEmail: customerOrder.customerEmail,
      
//       // معلومات المنتج
//       productType: supplierOrder.productType,
//       fuelType: supplierOrder.fuelType,
//       quantity: customerQty,
//       unit: supplierOrder.unit || 'لتر',
      
//       // معلومات الموقع
//       city,
//       area,
//       address,
      
//       // معلومات التوقيت
//       orderDate: new Date(),
//       loadingDate: supplierOrder.loadingDate || new Date(),
//       loadingTime: supplierOrder.loadingTime || '08:00',
//       arrivalDate: customerOrder.arrivalDate || new Date(),
//       arrivalTime: customerOrder.arrivalTime || '10:00',
      
//       // معلومات الشحن
//       driver: supplierOrder.driver,
//       driverName: supplierOrder.driverName,
//       driverPhone: supplierOrder.driverPhone,
//       vehicleNumber: supplierOrder.vehicleNumber,
      
//       // معلومات السعر
//       unitPrice: supplierOrder.unitPrice,
//       totalPrice: supplierOrder.unitPrice ? supplierOrder.unitPrice * customerQty : 0,
//       paymentMethod: supplierOrder.paymentMethod,
//       paymentStatus: supplierOrder.paymentStatus,
      
//       // حالة الطلب المدمج
//       status: 'تم الدمج',
      
//       // ملاحظات
//       notes: `طلب مدمج من:\n• طلب المورد: ${supplierOrder.orderNumber} (${supplierOrder.supplierName})\n• طلب العميل: ${customerOrder.orderNumber} (${customerOrder.customerName})\n${supplierOrder.notes ? 'ملاحظات المورد: ' + supplierOrder.notes + '\n' : ''}${customerOrder.notes ? 'ملاحظات العميل: ' + customerOrder.notes : ''}`.trim(),
      
//       supplierNotes: supplierOrder.supplierNotes,
//       customerNotes: customerOrder.customerNotes,
      
//       // معلومات الإنشاء
//       createdBy: req.user._id,
//       createdByName: req.user.name || 'النظام',
      
//       createdAt: new Date(),
//       updatedAt: new Date(),
//     };

//     const mergedOrder = new Order(mergedOrderData);
//     await mergedOrder.save({ session });

//     // =========================
//     // 9️⃣ تحديث الطلبات الأصلية
//     // =========================
    
//     // تحديث طلب المورد
//     supplierOrder.mergeStatus = 'مدمج';
//     supplierOrder.status = 'تم دمجه مع العميل';
//     supplierOrder.mergedWithOrderId = mergedOrder._id;
//     supplierOrder.mergedWithInfo = {
//       orderNumber: customerOrder.orderNumber,
//       partyName: customerOrder.customerName,
//       partyType: 'عميل',
//       mergedAt: new Date()
//     };
//     supplierOrder.mergedAt = new Date();
//     supplierOrder.updatedAt = new Date();
//     supplierOrder.notes = (supplierOrder.notes || '') + 
//       `\n[${new Date().toLocaleString('ar-SA')}] تم دمجه مع طلب العميل: ${customerOrder.orderNumber} (${customerOrder.customerName})`;
    
//     await supplierOrder.save({ session });

//     // تحديث طلب العميل
//     customerOrder.mergeStatus = 'مدمج';
//     customerOrder.status = 'تم دمجه مع المورد';
//     customerOrder.mergedWithOrderId = mergedOrder._id;
//     customerOrder.mergedWithInfo = {
//       orderNumber: supplierOrder.orderNumber,
//       partyName: supplierOrder.supplierName,
//       partyType: 'مورد',
//       mergedAt: new Date()
//     };
//     customerOrder.supplierOrderNumber = supplierOrder.supplierOrderNumber;
//     customerOrder.mergedAt = new Date();
//     customerOrder.updatedAt = new Date();
//     customerOrder.notes = (customerOrder.notes || '') + 
//       `\n[${new Date().toLocaleString('ar-SA')}] تم دمجه مع طلب المورد: ${supplierOrder.orderNumber} (${supplierOrder.supplierName})`;
    
//     await customerOrder.save({ session });

//     // =========================
//     // 🔟 تسجيل النشاطات
//     // =========================
//     try {
//       // نشاط للطلب المدموج
//       const mergedActivity = new Activity({
//         orderId: mergedOrder._id,
//         activityType: 'دمج',
//         description: `تم دمج طلب المورد ${supplierOrder.orderNumber} مع طلب العميل ${customerOrder.orderNumber}`,
//         details: {
//           supplierOrder: supplierOrder.orderNumber,
//           customerOrder: customerOrder.orderNumber,
//           mergedBy: req.user.name || 'النظام',
//           quantity: customerQty,
//           fuelType: supplierOrder.fuelType
//         },
//         performedBy: req.user._id,
//         performedByName: req.user.name || 'النظام',
//       });
//       await mergedActivity.save({ session });

//       // نشاط لطلب المورد
//       const supplierActivity = new Activity({
//         orderId: supplierOrder._id,
//         activityType: 'دمج',
//         description: `تم دمج الطلب مع طلب العميل ${customerOrder.orderNumber} (${customerOrder.customerName})`,
//         details: {
//           mergedOrder: mergedOrder.orderNumber,
//           customerOrder: customerOrder.orderNumber,
//           customerName: customerOrder.customerName,
//           mergedBy: req.user.name || 'النظام'
//         },
//         performedBy: req.user._id,
//         performedByName: req.user.name || 'النظام',
//       });
//       await supplierActivity.save({ session });

//       // نشاط لطلب العميل
//       const customerActivity = new Activity({
//         orderId: customerOrder._id,
//         activityType: 'دمج',
//         description: `تم دمج الطلب مع طلب المورد ${supplierOrder.orderNumber} (${supplierOrder.supplierName})`,
//         details: {
//           mergedOrder: mergedOrder.orderNumber,
//           supplierOrder: supplierOrder.orderNumber,
//           supplierName: supplierOrder.supplierName,
//           mergedBy: req.user.name || 'النظام'
//         },
//         performedBy: req.user._id,
//         performedByName: req.user.name || 'النظام',
//       });
//       await customerActivity.save({ session });

//     } catch (err) {
//       console.warn('⚠️ بعض النشاطات لم يتم حفظها:', err.message);
//     }

//     // =========================
//     // 📧 إرسال الإيميلات
//     // =========================
//     try {
//       const sendEmailPromises = [];
      
//       // إيميل للمورد
//       if (supplierOrder.supplierEmail || supplierOrder.supplier?.email) {
//         const supplierEmail = supplierOrder.supplierEmail || supplierOrder.supplier?.email;
//         const emailTemplate = `
//           <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px;">
//             <h2 style="color: #4CAF50;">✅ تم دمج طلبك مع عميل</h2>
//             <div style="background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0;">
//               <h3>تفاصيل الدمج</h3>
//               <p><strong>رقم طلبك:</strong> ${supplierOrder.orderNumber}</p>
//               <p><strong>اسم العميل:</strong> ${customerOrder.customerName}</p>
//               <p><strong>رقم طلب العميل:</strong> ${customerOrder.orderNumber}</p>
//               <p><strong>الكمية:</strong> ${customerQty} ${supplierOrder.unit}</p>
//               <p><strong>نوع الوقود:</strong> ${supplierOrder.fuelType}</p>
//               <p><strong>رقم الطلب المدموج:</strong> ${mergedOrder.orderNumber}</p>
//             </div>
//             <p>تم تحديث حالة طلبك إلى: <strong style="color: #9c27b0;">تم دمجه مع العميل</strong></p>
//           </div>
//         `;
        
//         sendEmailPromises.push(
//           sendEmail({
//             to: supplierEmail,
//             subject: `✅ تم دمج طلبك ${supplierOrder.orderNumber} مع عميل`,
//             html: emailTemplate,
//           })
//         );
//       }
      
//       // إيميل للعميل
//       if (customerOrder.customerEmail) {
//         const emailTemplate = `
//           <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px;">
//             <h2 style="color: #4CAF50;">✅ تم تخصيص مورد لطلبك</h2>
//             <div style="background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0;">
//               <h3>تفاصيل التخصيص</h3>
//               <p><strong>رقم طلبك:</strong> ${customerOrder.orderNumber}</p>
//               <p><strong>اسم المورد:</strong> ${supplierOrder.supplierName}</p>
//               <p><strong>رقم طلب المورد:</strong> ${supplierOrder.orderNumber}</p>
//               <p><strong>رقم طلب المورد (الخاص بالمورد):</strong> ${supplierOrder.supplierOrderNumber}</p>
//               <p><strong>الكمية:</strong> ${customerQty} ${supplierOrder.unit}</p>
//               <p><strong>نوع الوقود:</strong> ${supplierOrder.fuelType}</p>
//               <p><strong>رقم الطلب المدموج:</strong> ${mergedOrder.orderNumber}</p>
//             </div>
//             <p>تم تحديث حالة طلبك إلى: <strong style="color: #9c27b0;">تم دمجه مع المورد</strong></p>
//           </div>
//         `;
        
//         sendEmailPromises.push(
//           sendEmail({
//             to: customerOrder.customerEmail,
//             subject: `✅ تم تخصيص مورد لطلبك ${customerOrder.orderNumber}`,
//             html: emailTemplate,
//           })
//         );
//       }
      
//       // إيميل للمسؤولين
//       const adminUsers = await mongoose.model('User').find({
//         role: { $in: ['admin', 'manager'] },
//         isActive: true,
//         email: { $exists: true, $ne: '' }
//       }).session(session);
      
//       if (adminUsers.length > 0) {
//         const adminEmails = adminUsers.map(user => user.email);
//         const adminEmailTemplate = `
//           <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px;">
//             <h2 style="color: #2196F3;">📋 تقرير دمج طلبات</h2>
//             <div style="background: #f0f8ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
//               <h3>تفاصيل الدمج</h3>
//               <p><strong>تم بواسطة:</strong> ${req.user.name || 'النظام'}</p>
//               <p><strong>وقت الدمج:</strong> ${new Date().toLocaleString('ar-SA')}</p>
//               <hr>
//               <p><strong>طلب المورد:</strong> ${supplierOrder.orderNumber} (${supplierOrder.supplierName})</p>
//               <p><strong>طلب العميل:</strong> ${customerOrder.orderNumber} (${customerOrder.customerName})</p>
//               <p><strong>الطلب المدموج:</strong> ${mergedOrder.orderNumber}</p>
//               <p><strong>الكمية:</strong> ${customerQty} ${supplierOrder.unit}</p>
//               <p><strong>القيمة:</strong> ${mergedOrder.totalPrice ? mergedOrder.totalPrice.toLocaleString('ar-SA') : 0} ريال</p>
//             </div>
//           </div>
//         `;
        
//         sendEmailPromises.push(
//           sendEmail({
//             to: adminEmails,
//             subject: `📋 تم دمج طلبين: ${supplierOrder.orderNumber} مع ${customerOrder.orderNumber}`,
//             html: adminEmailTemplate,
//           })
//         );
//       }
      
//       // إرسال جميع الإيميلات
//       await Promise.all(sendEmailPromises);
      
//     } catch (emailError) {
//       console.error('❌ Failed to send merge emails:', emailError.message);
//       // لا نوقف العملية إذا فشل الإيميل
//     }

//     // =========================
//     // ✅ تأكيد العملية
//     // =========================
//     await session.commitTransaction();
//     session.endSession();

//     // =========================
//     // 📊 الاستجابة
//     // =========================
//     return res.status(200).json({
//       success: true,
//       message: 'تم دمج الطلبات بنجاح',
//       data: {
//         mergedOrder: {
//           _id: mergedOrder._id,
//           orderNumber: mergedOrder.orderNumber,
//           status: mergedOrder.status,
//           mergeStatus: mergedOrder.mergeStatus,
//           supplierName: mergedOrder.supplierName,
//           customerName: mergedOrder.customerName,
//           quantity: mergedOrder.quantity,
//           unit: mergedOrder.unit,
//           fuelType: mergedOrder.fuelType,
//           totalPrice: mergedOrder.totalPrice,
//           createdAt: mergedOrder.createdAt
//         },
//         supplierOrder: {
//           _id: supplierOrder._id,
//           orderNumber: supplierOrder.orderNumber,
//           status: supplierOrder.status,
//           mergeStatus: supplierOrder.mergeStatus,
//           mergedWith: supplierOrder.mergedWithInfo,
//           updatedAt: supplierOrder.updatedAt
//         },
//         customerOrder: {
//           _id: customerOrder._id,
//           orderNumber: customerOrder.orderNumber,
//           status: customerOrder.status,
//           mergeStatus: customerOrder.mergeStatus,
//           mergedWith: customerOrder.mergedWithInfo,
//           supplierOrderNumber: customerOrder.supplierOrderNumber,
//           updatedAt: customerOrder.updatedAt
//         }
//       }
//     });

//   } catch (error) {
//     // =========================
//     // ❌ معالجة الأخطاء
//     // =========================
//     await session.abortTransaction();
//     session.endSession();
    
//     console.error('❌ Error merging orders:', error);
    
//     return res.status(500).json({
//       success: false,
//       message: 'حدث خطأ أثناء دمج الطلبات',
//       error: process.env.NODE_ENV === 'development' ? error.message : undefined
//     });
//   }
// };





function idsEqual(left, right) {
  return String(left || '') === String(right || '');
}

function getPreviousSourceStatus(order) {
  const info = order?.mergedWithInfo && typeof order.mergedWithInfo === 'object'
    ? order.mergedWithInfo
    : {};
  const previousStatus =
    typeof info.previousStatus === 'string' ? info.previousStatus.trim() : '';

  if (previousStatus) {
    return previousStatus;
  }

  if (order?.orderSource === 'عميل') {
    return 'في انتظار التخصيص';
  }

  return 'تم الإنشاء';
}

function getPreviousSourceMergeStatus(order) {
  const info = order?.mergedWithInfo && typeof order.mergedWithInfo === 'object'
    ? order.mergedWithInfo
    : {};
  const previousMergeStatus =
    typeof info.previousMergeStatus === 'string'
      ? info.previousMergeStatus.trim()
      : '';

  if (
    previousMergeStatus &&
    previousMergeStatus !== 'مدمج' &&
    previousMergeStatus !== 'مكتمل'
  ) {
    return previousMergeStatus;
  }

  return 'منفصل';
}

function resolveMergedOrderLocation(supplierOrder, customerOrder) {
  if (customerOrder?.city && customerOrder?.area) {
    return {
      city: customerOrder.city,
      area: customerOrder.area,
      address:
        customerOrder.address ||
        `${customerOrder.city} - ${customerOrder.area}`,
    };
  }

  if (supplierOrder?.city && supplierOrder?.area) {
    return {
      city: supplierOrder.city,
      area: supplierOrder.area,
      address:
        supplierOrder.address ||
        `${supplierOrder.city} - ${supplierOrder.area}`,
    };
  }

  return {
    city: 'غير محدد',
    area: 'غير محدد',
    address: 'غير محدد',
  };
}

function buildMergedOrderNotes(supplierOrder, customerOrder, mergeNotes) {
  const lines = [
    'طلب مدمج من:',
    `• طلب المورد: ${supplierOrder.orderNumber} (${supplierOrder.supplierName || 'غير محدد'})`,
    `• طلب العميل: ${customerOrder.orderNumber} (${customerOrder.customerName || 'غير محدد'})`,
  ];

  if (mergeNotes) {
    lines.push(`ملاحظات الدمج: ${mergeNotes}`);
  }

  if (supplierOrder?.notes) {
    lines.push(`ملاحظات المورد: ${supplierOrder.notes}`);
  }

  if (customerOrder?.notes) {
    lines.push(`ملاحظات العميل: ${customerOrder.notes}`);
  }

  return lines.join('\n').trim();
}

function cloneMergedAttachments(attachments, user) {
  if (!Array.isArray(attachments)) {
    return [];
  }

  return attachments
    .filter((attachment) => attachment && attachment.path)
    .map((attachment) => ({
      filename: attachment.filename,
      path: attachment.path,
      uploadedAt: attachment.uploadedAt || new Date(),
      uploadedBy: attachment.uploadedBy || user?._id,
    }));
}

function appendOrderNote(order, message) {
  if (!message) {
    return;
  }

  const entry = `[${new Date().toLocaleString('ar-SA')}] ${message}`;
  order.notes = order.notes ? `${order.notes}\n${entry}` : entry;
}

function applyMergedOrderSnapshot(
  mergedOrder,
  supplierOrder,
  customerOrder,
  user,
  mergeNotes,
) {
  const customerQty = Number(customerOrder.quantity || 0);
  const location = resolveMergedOrderLocation(supplierOrder, customerOrder);
  const currentMergedInfo =
    mergedOrder.mergedWithInfo &&
        typeof mergedOrder.mergedWithInfo === 'object'
    ? mergedOrder.mergedWithInfo
    : {};
  const effectiveMergeNotes =
    typeof mergeNotes === 'string' && mergeNotes.trim()
    ? mergeNotes.trim()
    : mergedOrder.mergeNotes;

  mergedOrder.supplierOrderNumber = supplierOrder.supplierOrderNumber;
  mergedOrder.supplier = supplierOrder.supplier?._id || supplierOrder.supplier;
  mergedOrder.supplierName = supplierOrder.supplierName;
  mergedOrder.supplierPhone = supplierOrder.supplierPhone;
  mergedOrder.supplierCompany = supplierOrder.supplierCompany;
  mergedOrder.supplierContactPerson = supplierOrder.supplierContactPerson;
  mergedOrder.supplierAddress = supplierOrder.supplierAddress;
  mergedOrder.supplierEmail =
    supplierOrder.supplier?.email || supplierOrder.supplierEmail;
  mergedOrder.customer = customerOrder.customer?._id || customerOrder.customer;
  mergedOrder.customerName = customerOrder.customerName;
  mergedOrder.customerCode = customerOrder.customerCode;
  mergedOrder.customerPhone = customerOrder.customerPhone;
  mergedOrder.customerEmail =
    customerOrder.customer?.email || customerOrder.customerEmail;
  mergedOrder.customerAddress =
    customerOrder.customer?.address || customerOrder.address;
  mergedOrder.requestType = customerOrder.requestType || 'شراء';
  mergedOrder.productType = supplierOrder.productType;
  mergedOrder.fuelType = supplierOrder.fuelType;
  mergedOrder.quantity = customerQty;
  mergedOrder.unit = supplierOrder.unit || 'لتر';
  mergedOrder.city = location.city;
  mergedOrder.area = location.area;
  mergedOrder.address = location.address;
  mergedOrder.loadingDate =
    supplierOrder.loadingDate || mergedOrder.loadingDate || new Date();
  mergedOrder.loadingTime =
    supplierOrder.loadingTime || mergedOrder.loadingTime || '08:00';
  mergedOrder.arrivalDate =
    customerOrder.arrivalDate || mergedOrder.arrivalDate || new Date();
  mergedOrder.arrivalTime =
    customerOrder.arrivalTime || mergedOrder.arrivalTime || '10:00';
  mergedOrder.driver = supplierOrder.driver;
  mergedOrder.driverName = supplierOrder.driverName;
  mergedOrder.driverPhone = supplierOrder.driverPhone;
  mergedOrder.vehicleNumber = supplierOrder.vehicleNumber;
  mergedOrder.unitPrice = supplierOrder.unitPrice;
  mergedOrder.totalPrice = supplierOrder.unitPrice
    ? supplierOrder.unitPrice * customerQty
    : 0;
  mergedOrder.paymentMethod = supplierOrder.paymentMethod;
  mergedOrder.paymentStatus = supplierOrder.paymentStatus;
  mergedOrder.driverEarnings = supplierOrder.driverEarnings || 0;
  mergedOrder.attachments = cloneMergedAttachments(
    supplierOrder.attachments,
    user,
  );
  mergedOrder.notes = buildMergedOrderNotes(
    supplierOrder,
    customerOrder,
    effectiveMergeNotes,
  );
  mergedOrder.supplierNotes = supplierOrder.supplierNotes;
  mergedOrder.customerNotes = customerOrder.customerNotes;
  mergedOrder.mergeNotes = effectiveMergeNotes;
  mergedOrder.updatedAt = new Date();
  mergedOrder.mergedWithInfo = {
    ...currentMergedInfo,
    supplierOrderNumber: supplierOrder.orderNumber,
    customerOrderNumber: customerOrder.orderNumber,
    supplierName: supplierOrder.supplierName,
    customerName: customerOrder.customerName,
    mergedAt: currentMergedInfo.mergedAt || mergedOrder.mergedAt || new Date(),
    mergedBy: user?.name || user?.email || 'النظام',
    mergedOrderNumber: mergedOrder.orderNumber,
    lastUpdatedAt: new Date(),
  };
  mergedOrder.mergedAt = mergedOrder.mergedWithInfo.mergedAt;
}

function linkSourceOrderToMerged(order, partnerOrder, mergedOrder, user) {
  const currentInfo =
    order.mergedWithInfo && typeof order.mergedWithInfo === 'object'
    ? order.mergedWithInfo
    : {};
  const isAlreadyLinked = idsEqual(order.mergedWithOrderId, mergedOrder._id);
  const previousStatus =
    (typeof currentInfo.previousStatus === 'string' &&
        currentInfo.previousStatus.trim()) ||
    (!['تم دمجه مع العميل', 'تم دمجه مع المورد'].includes(order.status)
      ? order.status
      : '') ||
    getPreviousSourceStatus(order);
  const previousMergeStatus =
    (typeof currentInfo.previousMergeStatus === 'string' &&
        currentInfo.previousMergeStatus.trim()) ||
    (order.mergeStatus && !['مدمج', 'مكتمل'].includes(order.mergeStatus)
      ? order.mergeStatus
      : '') ||
    'منفصل';

  order.mergeStatus = 'مدمج';
  order.status = order.orderSource === 'مورد'
    ? 'تم دمجه مع العميل'
    : 'تم دمجه مع المورد';
  order.mergedWithOrderId = mergedOrder._id;
  order.mergedWithInfo = {
    ...currentInfo,
    orderNumber: partnerOrder.orderNumber,
    partyName: partnerOrder.orderSource === 'مورد'
      ? partnerOrder.supplierName
      : partnerOrder.customerName,
    partyType: partnerOrder.orderSource,
    mergedAt: currentInfo.mergedAt || order.mergedAt || new Date(),
    mergedBy: user?.name || user?.email || 'النظام',
    mergedOrderNumber: mergedOrder.orderNumber,
    previousStatus,
    previousMergeStatus,
    previousSupplierOrderNumber: order.orderSource === 'عميل'
      ? currentInfo.previousSupplierOrderNumber || order.supplierOrderNumber
      : currentInfo.previousSupplierOrderNumber,
    lastUpdatedAt: new Date(),
  };
  order.mergedAt = order.mergedWithInfo.mergedAt;
  order.updatedAt = new Date();

  if (order.orderSource === 'عميل' && partnerOrder.orderSource === 'مورد') {
    order.supplierOrderNumber = partnerOrder.supplierOrderNumber;
  }

  const partnerChanged = currentInfo.orderNumber !== partnerOrder.orderNumber;
  if (!isAlreadyLinked || partnerChanged) {
    const message = order.orderSource === 'مورد'
      ? `تم ربط الطلب مع طلب العميل: ${partnerOrder.orderNumber} (${partnerOrder.customerName || 'غير محدد'})`
      : `تم ربط الطلب مع طلب المورد: ${partnerOrder.orderNumber} (${partnerOrder.supplierName || 'غير محدد'})`;
    appendOrderNote(order, message);
  }
}

function restoreSeparatedOrder(order, reason) {
  const currentInfo =
    order.mergedWithInfo && typeof order.mergedWithInfo === 'object'
    ? order.mergedWithInfo
    : {};

  order.status = getPreviousSourceStatus(order);
  order.mergeStatus = getPreviousSourceMergeStatus(order);
  order.mergedWithOrderId = null;
  order.mergedWithInfo = null;
  order.mergedAt = null;
  order.updatedAt = new Date();

  if (order.orderSource === 'عميل') {
    order.supplierOrderNumber =
      currentInfo.previousSupplierOrderNumber || undefined;
  }

  if (order.entryChannel === 'movement' && order.orderSource === 'مورد') {
    order.movementCustomer = null;
    order.movementCustomerName = undefined;
    order.movementCustomerRequestDate = null;
    order.movementExpectedArrivalDate = null;
    order.movementCustomerOrderId = null;
    order.movementMergedOrderId = null;
    order.movementMergedOrderNumber = undefined;
    order.movementDirectedAt = null;
    order.movementDirectedBy = null;
    order.movementDirectedByName = undefined;
  }

  appendOrderNote(order, reason);
}

function generateMergedOrderNumber() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  const rand = Math.floor(1000 + Math.random() * 9000);
  return `MIX-${y}${m}${d}-${rand}`;
}

function applyMovementDispatchMetadata(
  supplierOrder,
  customerOrder,
  mergedOrder,
  user,
  customerRequestDate,
  expectedArrivalDate,
) {
  supplierOrder.entryChannel = 'movement';
  supplierOrder.movementCustomer = customerOrder.customer?._id || customerOrder.customer;
  supplierOrder.movementCustomerName =
    customerOrder.customerName || customerOrder.customer?.name;
  supplierOrder.movementCustomerRequestDate = customerRequestDate;
  supplierOrder.movementExpectedArrivalDate = expectedArrivalDate;
  supplierOrder.movementCustomerOrderId = customerOrder._id;
  supplierOrder.movementMergedOrderId = mergedOrder._id;
  supplierOrder.movementMergedOrderNumber = mergedOrder.orderNumber;
  supplierOrder.movementDirectedAt = new Date();
  supplierOrder.movementDirectedBy = user?._id || null;
  supplierOrder.movementDirectedByName = user?.name || user?.email || 'النظام';
}

async function buildMovementCustomerOrder({
  session,
  supplierOrder,
  customerDoc,
  user,
  customerRequestDate,
  expectedArrivalDate,
  requestType,
}) {
  const customerOrder = new Order({
    orderSource: 'عميل',
    mergeStatus: 'منفصل',
    entryChannel: 'movement',
    customer: customerDoc._id,
    customerName: customerDoc.name,
    customerCode: customerDoc.code,
    customerPhone: customerDoc.phone,
    customerEmail: customerDoc.email,
    customerAddress: customerDoc.address,
    requestType: requestType || 'شراء',
    supplier: supplierOrder.supplier?._id || supplierOrder.supplier,
    supplierName: supplierOrder.supplierName,
    supplierPhone: supplierOrder.supplierPhone,
    supplierCompany: supplierOrder.supplierCompany,
    supplierContactPerson: supplierOrder.supplierContactPerson,
    supplierAddress: supplierOrder.supplierAddress,
    supplierOrderNumber: supplierOrder.supplierOrderNumber,
    productType: supplierOrder.productType,
    fuelType: supplierOrder.fuelType,
    quantity: supplierOrder.quantity,
    unit: supplierOrder.unit || 'لتر',
    city: customerDoc.city || supplierOrder.city || 'غير محدد',
    area: customerDoc.area || supplierOrder.area || 'غير محدد',
    address:
      customerDoc.address ||
      supplierOrder.address ||
      `${customerDoc.city || supplierOrder.city || 'غير محدد'} - ${customerDoc.area || supplierOrder.area || 'غير محدد'}`,
    orderDate: customerRequestDate,
    loadingDate: supplierOrder.loadingDate || customerRequestDate,
    loadingTime: supplierOrder.loadingTime || '08:00',
    arrivalDate: expectedArrivalDate,
    arrivalTime: supplierOrder.arrivalTime || '10:00',
    notes: supplierOrder.notes,
    status: 'في انتظار التخصيص',
    createdBy: user._id,
    createdByName: user.name || user.email,
  });

  await customerOrder.save({ session });
  return customerOrder;
}

async function createMergedOrderFromSourceOrders({
  session,
  supplierOrder,
  customerOrder,
  user,
  mergeNotes,
}) {
  if (supplierOrder.orderSource !== 'مورد') {
    throw new Error('الطلب الأول يجب أن يكون طلب مورد');
  }
  if (customerOrder.orderSource !== 'عميل') {
    throw new Error('الطلب الثاني يجب أن يكون طلب عميل');
  }

  const supplierQty = Number(supplierOrder.quantity || 0);
  const customerQty = Number(customerOrder.quantity || 0);
  if (supplierQty < customerQty) {
    throw new Error('كمية طلب المورد أقل من كمية طلب العميل');
  }
  if (
    supplierOrder.fuelType &&
    customerOrder.fuelType &&
    supplierOrder.fuelType !== customerOrder.fuelType
  ) {
    throw new Error('نوع الوقود غير متطابق بين الطلبين');
  }

  const mergedOrder = new Order({
    orderSource: 'مدمج',
    mergeStatus: 'مدمج',
    entryChannel: supplierOrder.entryChannel === 'movement' ? 'movement' : 'manual',
    orderNumber: generateMergedOrderNumber(),
    status: 'تم الدمج',
    quantity: customerQty,
    unit: supplierOrder.unit || 'لتر',
    orderDate: new Date(),
    loadingDate: supplierOrder.loadingDate || new Date(),
    loadingTime: supplierOrder.loadingTime || '08:00',
    arrivalDate: customerOrder.arrivalDate || new Date(),
    arrivalTime: customerOrder.arrivalTime || '10:00',
    city: 'غير محدد',
    area: 'غير محدد',
    address: 'غير محدد',
    createdBy: user._id,
    createdByName: user.name || user.email,
  });

  applyMergedOrderSnapshot(
    mergedOrder,
    supplierOrder,
    customerOrder,
    user,
    mergeNotes,
  );

  await mergedOrder.save({ session });

  const executionTimestamp = new Date();
  mergedOrder.status = 'تم التنفيذ';
  mergedOrder.mergeStatus = 'مكتمل';
  mergedOrder.completedAt = executionTimestamp;
  mergedOrder.updatedAt = executionTimestamp;
  await mergedOrder.save({ session });

  linkSourceOrderToMerged(supplierOrder, customerOrder, mergedOrder, user);
  linkSourceOrderToMerged(customerOrder, supplierOrder, mergedOrder, user);
  await supplierOrder.save({ session });
  await customerOrder.save({ session });

  return mergedOrder;
}

exports.mergeOrders = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    const { supplierOrderId, customerOrderId, mergeNotes } = req.body;

    // =========================
    // 1️⃣ التحقق من المدخلات
    // =========================
    if (!supplierOrderId || !customerOrderId) {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'معرف طلب المورد ومعرف طلب العميل مطلوبان',
      });
    }

    if (supplierOrderId === customerOrderId) {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'لا يمكن دمج الطلب مع نفسه',
      });
    }

    // =========================
    // 2️⃣ جلب الطلبات مع جميع البيانات
    // =========================
    const supplierOrder = await Order.findById(supplierOrderId)
      .populate('supplier', 'name company contactPerson phone email address')
      .populate('createdBy', 'name email')
      .session(session);
    
    const customerOrder = await Order.findById(customerOrderId)
      .populate('customer', 'name code phone email city area address')
      .populate('createdBy', 'name email')
      .session(session);

    if (!supplierOrder || !customerOrder) {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(404).json({
        success: false,
        message: 'أحد الطلبات غير موجود',
      });
    }

    // =========================
    // 3️⃣ التحقق من أنواع الطلبات
    // =========================
    if (supplierOrder.orderSource !== 'مورد') {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'الطلب الأول يجب أن يكون طلب مورد',
      });
    }

    if (customerOrder.orderSource !== 'عميل') {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'الطلب الثاني يجب أن يكون طلب عميل',
      });
    }

    // =========================
    // 4️⃣ التحقق من حالة الدمج
    // =========================
    if (supplierOrder.mergeStatus !== 'منفصل' || customerOrder.mergeStatus !== 'منفصل') {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'أحد الطلبات تم دمجه مسبقًا',
      });
    }

    // =========================
    // 5️⃣ التحقق من التوافق
    // =========================
    if (supplierOrder.fuelType !== customerOrder.fuelType) {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'نوع الوقود غير متطابق',
      });
    }

    const supplierQty = Number(supplierOrder.quantity || 0);
    const customerQty = Number(customerOrder.quantity || 0);

    if (supplierQty < customerQty) {
      await session.abortTransaction();
      session.endSession();
      
      return res.status(400).json({
        success: false,
        message: 'كمية المورد أقل من كمية طلب العميل',
      });
    }

    // =========================
    // 6️⃣ إنشاء رقم الطلب المدموج
    // =========================
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    const rand = Math.floor(1000 + Math.random() * 9000);
    const mergedOrderNumber = `MIX-${y}${m}${d}-${rand}`;

    // =========================
    // 7️⃣ تحديد الموقع
    // =========================
    let city, area, address;

    if (customerOrder.city && customerOrder.area) {
      city = customerOrder.city;
      area = customerOrder.area;
      address = customerOrder.address || `${city} - ${area}`;
    } else if (supplierOrder.city && supplierOrder.area) {
      city = supplierOrder.city;
      area = supplierOrder.area;
      address = supplierOrder.address || `${city} - ${area}`;
    } else {
      city = 'غير محدد';
      area = 'غير محدد';
      address = 'غير محدد';
    }

    // =========================
    // 8️⃣ إنشاء الطلب المدموج
    // =========================
    const mergedOrderData = {
      orderSource: 'مدمج',
      mergeStatus: 'مدمج',
      orderNumber: mergedOrderNumber,
      
      // معلومات الدمج
      mergedWithOrderId: null,
      mergedWithInfo: {
        supplierOrderNumber: supplierOrder.orderNumber,
        customerOrderNumber: customerOrder.orderNumber,
        supplierName: supplierOrder.supplierName,
        customerName: customerOrder.customerName,
        mergedAt: new Date(),
        mergedBy: req.user.name || req.user.email
      },
      
      // معلومات المورد
      supplierOrderNumber: supplierOrder.supplierOrderNumber,
      supplier: supplierOrder.supplier?._id || supplierOrder.supplier,
      supplierName: supplierOrder.supplierName,
      supplierPhone: supplierOrder.supplierPhone,
      supplierCompany: supplierOrder.supplierCompany,
      supplierContactPerson: supplierOrder.supplierContactPerson,
      supplierAddress: supplierOrder.supplierAddress,
      supplierEmail: supplierOrder.supplier?.email || supplierOrder.supplierEmail,
      
      // معلومات العميل
      customer: customerOrder.customer?._id || customerOrder.customer,
      customerName: customerOrder.customerName,
      customerCode: customerOrder.customerCode,
      customerPhone: customerOrder.customerPhone,
      customerEmail: customerOrder.customer?.email || customerOrder.customerEmail,
      customerAddress: customerOrder.customer?.address || customerOrder.address,
      requestType: customerOrder.requestType || 'شراء',
      
      // معلومات المنتج
      productType: supplierOrder.productType,
      fuelType: supplierOrder.fuelType,
      quantity: customerQty,
      unit: supplierOrder.unit || 'لتر',
      
      // معلومات الموقع
      city,
      area,
      address,
      
      // معلومات التوقيت
      orderDate: new Date(),
      loadingDate: supplierOrder.loadingDate || new Date(),
      loadingTime: supplierOrder.loadingTime || '08:00',
      arrivalDate: customerOrder.arrivalDate || new Date(),
      arrivalTime: customerOrder.arrivalTime || '10:00',
      
      // معلومات الشحن
      driver: supplierOrder.driver,
      driverName: supplierOrder.driverName,
      driverPhone: supplierOrder.driverPhone,
      vehicleNumber: supplierOrder.vehicleNumber,
      
      // معلومات السعر
      unitPrice: supplierOrder.unitPrice,
      totalPrice: supplierOrder.unitPrice ? supplierOrder.unitPrice * customerQty : 0,
      paymentMethod: supplierOrder.paymentMethod,
      paymentStatus: supplierOrder.paymentStatus,
      driverEarnings: supplierOrder.driverEarnings || 0,

      attachments: (supplierOrder.attachments || []).map((attachment) => ({
        filename: attachment.filename,
        path: attachment.path,
        uploadedAt: attachment.uploadedAt || new Date(),
        uploadedBy: attachment.uploadedBy || req.user._id,
      })),
      
      // حالة الطلب المدمج
      status: 'تم الدمج',
      
      // ملاحظات
      notes: `طلب مدمج من:
• طلب المورد: ${supplierOrder.orderNumber} (${supplierOrder.supplierName})
• طلب العميل: ${customerOrder.orderNumber} (${customerOrder.customerName})
${mergeNotes ? 'ملاحظات الدمج: ' + mergeNotes + '\n' : ''}
${supplierOrder.notes ? 'ملاحظات المورد: ' + supplierOrder.notes + '\n' : ''}
${customerOrder.notes ? 'ملاحظات العميل: ' + customerOrder.notes : ''}`.trim(),
      
      supplierNotes: supplierOrder.supplierNotes,
      customerNotes: customerOrder.customerNotes,
      mergeNotes: mergeNotes,
      
      // معلومات الإنشاء
      createdBy: req.user._id,
      createdByName: req.user.name || req.user.email,
      
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const mergedOrder = new Order(mergedOrderData);
    await mergedOrder.save({ session });

    const executionTimestamp = new Date();
    mergedOrder.status = 'تم التنفيذ';
    mergedOrder.mergeStatus = 'مكتمل';
    mergedOrder.completedAt = executionTimestamp;
    mergedOrder.updatedAt = executionTimestamp;
    await mergedOrder.save({ session });

    // =========================
    // 9️⃣ تحديث الطلبات الأصلية
    // =========================
    
    // تحديث طلب المورد
    linkSourceOrderToMerged(
      supplierOrder,
      customerOrder,
      mergedOrder,
      req.user,
    );
    await supplierOrder.save({ session });

    // تحديث طلب العميل
    linkSourceOrderToMerged(
      customerOrder,
      supplierOrder,
      mergedOrder,
      req.user,
    );
    await customerOrder.save({ session });

    // =========================
    // 🔟 تسجيل النشاطات
    // =========================
    try {
      // نشاط للطلب المدموج
      const mergedActivity = new Activity({
        orderId: mergedOrder._id,
        activityType: 'دمج',
        description: `تم دمج طلب المورد ${supplierOrder.orderNumber} مع طلب العميل ${customerOrder.orderNumber}`,
        details: {
          supplierOrder: supplierOrder.orderNumber,
          customerOrder: customerOrder.orderNumber,
          mergedOrder: mergedOrder.orderNumber,
          mergedBy: req.user.name || req.user.email,
          quantity: customerQty,
          fuelType: supplierOrder.fuelType,
          totalPrice: mergedOrder.totalPrice
        },
        performedBy: req.user._id,
        performedByName: req.user.name || req.user.email,
      });
      await mergedActivity.save({ session });

      // نشاط لطلب المورد
      const supplierActivity = new Activity({
        orderId: supplierOrder._id,
        activityType: 'دمج',
        description: `تم دمج الطلب مع طلب العميل ${customerOrder.orderNumber} (${customerOrder.customerName})`,
        details: {
          mergedOrder: mergedOrder.orderNumber,
          customerOrder: customerOrder.orderNumber,
          customerName: customerOrder.customerName,
          mergedBy: req.user.name || req.user.email,
          quantityUsed: customerQty,
          remainingQuantity: supplierQty - customerQty
        },
        performedBy: req.user._id,
        performedByName: req.user.name || req.user.email,
      });
      await supplierActivity.save({ session });

      // نشاط لطلب العميل
      const customerActivity = new Activity({
        orderId: customerOrder._id,
        activityType: 'دمج',
        description: `تم دمج الطلب مع طلب المورد ${supplierOrder.orderNumber} (${supplierOrder.supplierName})`,
        details: {
          mergedOrder: mergedOrder.orderNumber,
          supplierOrder: supplierOrder.orderNumber,
          supplierName: supplierOrder.supplierName,
          mergedBy: req.user.name || req.user.email,
          quantity: customerQty,
          unitPrice: supplierOrder.unitPrice,
          totalPrice: mergedOrder.totalPrice
        },
        performedBy: req.user._id,
        performedByName: req.user.name || req.user.email,
      });
      await customerActivity.save({ session });

    } catch (err) {
      console.warn('⚠️ بعض النشاطات لم يتم حفظها:', err.message);
    }

    // =========================
    // 📧 جلب جميع المستخدمين المسجلين من نموذج User
    // =========================
    const User = mongoose.model('User');
   const owners = await User.find({
  role: 'owner',
  email: { $exists: true, $ne: '' }
}).select('name email role company').lean();

console.log(`📋 جاري إرسال بريد الدمج إلى ${owners.length} Owner`);

    // =========================
    // 📧 إنشاء قالب البريد الإلكتروني الشامل
    // =========================
    const createMergeEmailTemplate = () => {
      const formatDate = (date) => {
        if (!date) return 'غير محدد';
        const d = new Date(date);
        return d.toLocaleDateString('ar-SA', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric'
        });
      };

      const formatTime = (time) => time || 'غير محدد';
      
      const formatCurrency = (amount) => {
        if (!amount) return '0.00 ريال';
        return amount.toLocaleString('ar-SA', {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        }) + ' ريال';
      };

      const formatRole = (role) => {
        const roles = {
          'admin': 'مدير النظام',
          'employee': 'موظف',
          'viewer': 'مشاهد'
        };
        return roles[role] || role;
      };

      return `
        <!DOCTYPE html>
        <html dir="rtl" lang="ar">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>📊 إشعار دمج طلبات</title>
         <style>
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    
    body {
        background-color: #f5f7fa;
        line-height: 1.6;
        color: #333;
    }
    
    .email-container {
        max-width: 900px;
        margin: 30px auto;
        background-color: #ffffff;
        border-radius: 15px;
        overflow: hidden;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
    }
    
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 40px 30px;
        text-align: center;
        border-bottom: 5px solid #4a5568;
    }
    
    .header h1 {
        font-size: 28px;
        margin-bottom: 10px;
        font-weight: 700;
    }
    
    .header .subtitle {
        font-size: 16px;
        opacity: 0.9;
        margin-top: 5px;
    }
    
    .order-number {
        background: #4CAF50;
        color: white;
        padding: 8px 20px;
        border-radius: 25px;
        display: inline-block;
        margin-top: 15px;
        font-weight: bold;
        font-size: 18px;
        box-shadow: 0 4px 15px rgba(76, 175, 80, 0.3);
    }
    
    .content {
        padding: 40px;
    }
    
    .user-badge {
        background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        color: white;
        padding: 20px;
        border-radius: 10px;
        text-align: center;
        margin-bottom: 30px;
    }
    
    .user-badge h3 {
        font-size: 22px;
        margin-bottom: 10px;
    }
    
    .user-count {
        font-size: 28px;
        font-weight: bold;
        margin: 10px 0;
    }
    
    .section {
        margin-bottom: 35px;
        padding: 25px;
        border-radius: 10px;
        background-color: #f8f9fa;
        border-left: 5px solid #667eea;
    }
    
    .section-title {
        color: #2d3748;
        font-size: 20px;
        margin-bottom: 20px;
        padding-bottom: 10px;
        border-bottom: 2px solid #e2e8f0;
        font-weight: 600;
    }
    
    .info-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        gap: 20px;
        margin-top: 15px;
    }
    
    .info-item {
        background: white;
        padding: 20px;
        border-radius: 10px;
        box-shadow: 0 3px 10px rgba(0,0,0,0.08);
        transition: transform 0.3s ease, box-shadow 0.3s ease;
        border-top: 4px solid transparent;
    }
    
    .info-item:hover {
        transform: translateY(-2px);
        box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    }
    
    .info-label {
        color: #718096;
        font-size: 14px;
        margin-bottom: 8px;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 8px;
    }
    
    .info-value {
        color: #2d3748;
        font-size: 17px;
        font-weight: 600;
        margin-bottom: 12px;
    }
    
    .info-details {
        font-size: 13px;
        color: #4a5568;
        line-height: 1.5;
        margin-top: 10px;
        padding-top: 10px;
        border-top: 1px solid #e2e8f0;
    }
    
    .info-details div {
        margin-bottom: 6px;
        display: flex;
        align-items: center;
        gap: 6px;
    }
    
    .info-details strong {
        color: #2d3748;
        min-width: 90px;
        font-size: 12px;
    }
    
    .highlight {
        background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        color: white;
        padding: 25px;
        border-radius: 10px;
        text-align: center;
        margin: 30px 0;
    }
    
    .highlight h3 {
        font-size: 22px;
        margin-bottom: 10px;
    }
    
    .footer {
        background: #2d3748;
        color: white;
        padding: 25px;
        text-align: center;
        margin-top: 40px;
        border-top: 5px solid #4a5568;
    }
    
    .footer p {
        margin: 10px 0;
        opacity: 0.8;
    }
    
    .logo {
        font-size: 24px;
        font-weight: bold;
        color: #667eea;
        margin-bottom: 10px;
    }
    
    .timeline {
        position: relative;
        padding: 20px 0;
    }
    
    .timeline-item {
        position: relative;
        padding-left: 30px;
        margin-bottom: 20px;
    }
    
    .timeline-item:before {
        content: '';
        position: absolute;
        left: 0;
        top: 5px;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: #667eea;
    }
    
    .timeline-item:after {
        content: '';
        position: absolute;
        left: 5px;
        top: 5px;
        width: 2px;
        height: 100%;
        background: #e2e8f0;
    }
    
    .timeline-item:last-child:after {
        display: none;
    }
    
    .status-badge {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 12px;
        font-weight: 600;
        margin-right: 8px;
    }
    
    .status-completed {
        background: #d4edda;
        color: #155724;
    }
    
    .status-active {
        background: #d1ecf1;
        color: #0c5460;
    }
    
    .status-merged {
        background: #e2e3e5;
        color: #383d41;
    }
    
    .payment-status {
        padding: 3px 10px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: 600;
        display: inline-block;
    }
    
    .payment-paid {
        background: #d4edda;
        color: #155724;
    }
    
    .payment-partial {
        background: #fff3cd;
        color: #856404;
    }
    
    .payment-pending {
        background: #f8d7da;
        color: #721c24;
    }
    
    .icon {
        font-size: 14px;
        margin-right: 5px;
    }
    
    .supplier-item {
        border-top-color: #1890ff;
    }
    
    .customer-item {
        border-top-color: #52c41a;
    }
    
    .driver-item {
        border-top-color: #fa8c16;
    }
    
    .product-item {
        border-top-color: #722ed1;
    }
    
    .timing-item {
        border-top-color: #13c2c2;
    }
    
    .payment-item {
        border-top-color: #fa541c;
    }
    
    .compact-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 15px;
        margin-top: 15px;
    }
    
    .compact-item {
        background: white;
        padding: 15px;
        border-radius: 8px;
        box-shadow: 0 2px 5px rgba(0,0,0,0.05);
    }
    
    @media (max-width: 768px) {
        .content {
            padding: 20px;
        }
        
        .header {
            padding: 30px 20px;
        }
        
        .header h1 {
            font-size: 22px;
        }
        
        .info-grid {
            grid-template-columns: 1fr;
            gap: 15px;
        }
        
        .info-item {
            padding: 15px;
        }
        
        .compact-grid {
            grid-template-columns: 1fr;
            gap: 10px;
        }
        
        .user-count {
            font-size: 24px;
        }
        
        .section-title {
            font-size: 18px;
        }
        
        .info-value {
            font-size: 16px;
        }
        
        .info-details {
            font-size: 12px;
        }
    }
    
    @media (max-width: 480px) {
        .email-container {
            margin: 10px;
            border-radius: 10px;
        }
        
        .header {
            padding: 20px 15px;
        }
        
        .content {
            padding: 15px;
        }
        
        .section {
            padding: 15px;
            margin-bottom: 25px;
        }
        
        .info-details div {
            flex-direction: column;
            align-items: flex-start;
            gap: 2px;
        }
        
        .info-details strong {
            min-width: auto;
        }
    }
    
    .contact-info {
        background: #f8f9fa;
        border-radius: 8px;
        padding: 15px;
        margin-top: 15px;
        border-left: 4px solid #4CAF50;
    }
    
    .contact-info h4 {
        margin-bottom: 10px;
        color: #2d3748;
        font-size: 16px;
    }
    
    .qr-code {
        text-align: center;
        margin: 20px 0;
        padding: 20px;
        background: white;
        border-radius: 10px;
        border: 2px dashed #cbd5e0;
    }
    
    .qr-code h4 {
        margin-bottom: 15px;
        color: #4a5568;
    }
</style>
        </head>
        <body>
            <div class="email-container">
                <div class="header">
                    <h1>📊 إشعار دمج طلبات</h1>
                    <p class="subtitle"></p>
                    <div class="order-number">${mergedOrder.orderNumber}</div>
                </div>
                
                <div class="content">
                    <div class="user-badge">
                        <h3></h3>
                        <div class="user-count">${owners.length} Owner</div>

                        <p></p>
                    </div>
                    
                  <div class="section">
    <h2 class="section-title">📋 ملخص عملية الدمج</h2>
    <div class="info-grid">
        <div class="info-item">
            <div class="info-label">تاريخ الدمج</div>
            <div class="info-value">${formatDate(new Date())}</div>
        </div>
        <div class="info-item">
            <div class="info-label">تم الدمج بواسطة</div>
            <div class="info-value">${req.user.name || req.user.email}</div>
        </div>
        <div class="info-item">
            <div class="info-label">حالة الدمج</div>
            <div class="info-value">
                <span class="status-badge status-completed">✅ تم بنجاح</span>
            </div>
        </div>
        <div class="info-item">
            <div class="info-label">رقم الطلب المدموج</div>
            <div class="info-value">${mergedOrder.orderNumber}</div>
        </div>
        
        <!-- بيانات المورد -->
        <div class="info-item" style="background: #f0f9ff; border-right: 4px solid #1890ff;">
            <div class="info-label">🏭 المورد</div>
            <div class="info-value">${supplierOrder.supplierName || 'غير محدد'}</div>
            <div style="margin-top: 8px; font-size: 13px; color: #4a5568;">
                ${supplierOrder.supplierCompany ? `<div><strong>الشركة:</strong> ${supplierOrder.supplierCompany}</div>` : ''}
                ${supplierOrder.supplierContactPerson ? `<div><strong>الشخص المسؤول:</strong> ${supplierOrder.supplierContactPerson}</div>` : ''}
                ${supplierOrder.supplierPhone ? `<div><strong>📞 الهاتف:</strong> ${supplierOrder.supplierPhone}</div>` : ''}
                ${supplierOrder.supplier?.email ? `<div><strong>✉️ الإيميل:</strong> ${supplierOrder.supplier.email}</div>` : ''}
                ${supplierOrder.supplierOrderNumber ? `<div><strong>رقم طلب المورد:</strong> ${supplierOrder.supplierOrderNumber}</div>` : ''}
            </div>
        </div>
        
        <!-- بيانات العميل -->
        <div class="info-item" style="background: #f0fff4; border-right: 4px solid #52c41a;">
            <div class="info-label">👤 العميل</div>
            <div class="info-value">${customerOrder.customerName || 'غير محدد'}</div>
            <div style="margin-top: 8px; font-size: 13px; color: #4a5568;">
                ${customerOrder.customerCode ? `<div><strong>الكود:</strong> ${customerOrder.customerCode}</div>` : ''}
                ${customerOrder.customerPhone ? `<div><strong>📞 الهاتف:</strong> ${customerOrder.customerPhone}</div>` : ''}
                ${customerOrder.customer?.email ? `<div><strong>✉️ الإيميل:</strong> ${customerOrder.customer.email}</div>` : ''}
                ${customerOrder.requestType ? `<div><strong>نوع الطلب:</strong> ${customerOrder.requestType}</div>` : ''}
                <div><strong>الموقع:</strong> ${city || 'غير محدد'} - ${area || 'غير محدد'}</div>
            </div>
        </div>
        
        <!-- بيانات السائق -->
        <div class="info-item" style="background: #fff7e6; border-right: 4px solid #fa8c16;">
            <div class="info-label">🚚 السائق</div>
            <div class="info-value">${supplierOrder.driverName || 'لم يتم التحديد بعد'}</div>
            <div style="margin-top: 8px; font-size: 13px; color: #4a5568;">
                ${supplierOrder.driverPhone ? `<div><strong>📞 الهاتف:</strong> ${supplierOrder.driverPhone}</div>` : ''}
                ${supplierOrder.vehicleNumber ? `<div><strong>رقم المركبة:</strong> ${supplierOrder.vehicleNumber}</div>` : ''}
                ${supplierOrder.driver ? `
                    <div><strong>أجر السائق:</strong> ${supplierOrder.driverEarnings ? formatCurrency(supplierOrder.driverEarnings) : 'غير محدد'}</div>
                ` : ''}
                ${supplierOrder.deliveryDuration ? `<div><strong>مدة التوصيل:</strong> ${supplierOrder.deliveryDuration}</div>` : ''}
                ${supplierOrder.distance ? `<div><strong>المسافة:</strong> ${supplierOrder.distance} كم</div>` : ''}
            </div>
        </div>
        
        <!-- معلومات المنتج والكمية -->
        <div class="info-item" style="background: #f9f0ff; border-right: 4px solid #722ed1;">
            <div class="info-label">⛽ المنتج</div>
            <div class="info-value">${supplierOrder.fuelType || 'غير محدد'}</div>
            <div style="margin-top: 8px; font-size: 13px; color: #4a5568;">
                <div><strong>نوع المنتج:</strong> ${supplierOrder.productType || 'غير محدد'}</div>
                <div><strong>الكمية المدموجة:</strong> ${customerQty} ${supplierOrder.unit || 'لتر'}</div>
                <div><strong>السعر للوحدة:</strong> ${formatCurrency(supplierOrder.unitPrice)}</div>
                <div><strong>القيمة الإجمالية:</strong> ${formatCurrency(mergedOrder.totalPrice)}</div>
            </div>
        </div>
        
        <!-- معلومات التوقيت -->
        <div class="info-item" style="background: #e6fffb; border-right: 4px solid #13c2c2;">
            <div class="info-label">⏰ مواعيد التسليم</div>
            <div style="margin-top: 5px; font-size: 13px;">
                <div style="margin-bottom: 10px; padding: 8px; background: white; border-radius: 6px;">
                    <div><strong>التحميل:</strong></div>
                    <div>${formatDate(supplierOrder.loadingDate)}</div>
                    <div>${supplierOrder.loadingTime}</div>
                </div>
                <div style="padding: 8px; background: white; border-radius: 6px;">
                    <div><strong>الوصول المتوقع:</strong></div>
                    <div>${formatDate(customerOrder.arrivalDate)}</div>
                    <div>${customerOrder.arrivalTime}</div>
                </div>
            </div>
        </div>
        
        <!-- معلومات الدفع -->
        <div class="info-item" style="background: #fff2e8; border-right: 4px solid #fa541c;">
            <div class="info-label">💳 معلومات الدفع</div>
            <div style="margin-top: 8px; font-size: 13px; color: #4a5568;">
                <div><strong>طريقة الدفع:</strong> ${supplierOrder.paymentMethod || 'غير محدد'}</div>
                <div><strong>حالة الدفع:</strong> 
                    <span style="
                        padding: 2px 8px;
                        border-radius: 12px;
                        font-size: 11px;
                        font-weight: 600;
                        ${supplierOrder.paymentStatus === 'مدفوع' ? 'background: #d4edda; color: #155724;' : 
                          supplierOrder.paymentStatus === 'جزئي' ? 'background: #fff3cd; color: #856404;' : 
                          'background: #f8d7da; color: #721c24;'}
                    ">
                        ${supplierOrder.paymentStatus || 'غير محدد'}
                    </span>
                </div>
                <div><strong>المبلغ الإجمالي:</strong> ${formatCurrency(mergedOrder.totalPrice)}</div>
                <div><strong>تاريخ الاستحقاق:</strong> ${formatDate(mergedOrder.orderDate)}</div>
            </div>
        </div>
    </div>
</div>
                    
                    <div class="section">
                        <h2 class="section-title">🔄 تفاصيل الطلبات المدمجة</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">📦 طلب المورد</div>
                                <div class="info-value">${supplierOrder.orderNumber}</div>
                                <div style="margin-top: 8px; font-size: 14px; color: #4a5568;">
                                    <div><strong>المورد:</strong> ${supplierOrder.supplierName}</div>
                                    <div><strong>الشركة:</strong> ${supplierOrder.supplierCompany || 'غير محدد'}</div>
                                    <div><strong>الكمية الأصلية:</strong> ${supplierQty} ${supplierOrder.unit || 'لتر'}</div>
                                    <div><strong>الحالة:</strong> <span class="status-badge status-merged">تم الدمج</span></div>
                                    ${supplierOrder.supplierOrderNumber ? 
                                        `<div><strong>رقم طلب المورد:</strong> ${supplierOrder.supplierOrderNumber}</div>` : ''}
                                </div>
                            </div>
                            
                            <div class="info-item">
                                <div class="info-label">👤 طلب العميل</div>
                                <div class="info-value">${customerOrder.orderNumber}</div>
                                <div style="margin-top: 8px; font-size: 14px; color: #4a5568;">
                                    <div><strong>العميل:</strong> ${customerOrder.customerName}</div>
                                    <div><strong>الكود:</strong> ${customerOrder.customerCode || 'غير محدد'}</div>
                                    <div><strong>الكمية المطلوبة:</strong> ${customerQty} ${customerOrder.unit || supplierOrder.unit || 'لتر'}</div>
                                    <div><strong>نوع الطلب:</strong> ${customerOrder.requestType || 'غير محدد'}</div>
                                    <div><strong>الحالة:</strong> <span class="status-badge status-merged">تم الدمج</span></div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="highlight">
                        <h3>💰 القيمة الإجمالية للطلب المدموج</h3>
                        <p style="font-size: 32px; font-weight: bold; margin: 10px 0;">
                            ${formatCurrency(mergedOrder.totalPrice)}
                        </p>
                        <p>${customerQty} ${supplierOrder.unit || 'لتر'} × ${formatCurrency(supplierOrder.unitPrice)}</p>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">⛽ تفاصيل المنتج</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">نوع المنتج</div>
                                <div class="info-value">${supplierOrder.productType || 'غير محدد'}</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">نوع الوقود</div>
                                <div class="info-value">${supplierOrder.fuelType || 'غير محدد'}</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">الكمية المدموجة</div>
                                <div class="info-value">${customerQty} ${supplierOrder.unit || 'لتر'}</div>
                            </div>
                            <div class="info-item">
                                <div class="info-label">الوحدة</div>
                                <div class="info-value">${supplierOrder.unit || 'لتر'}</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">📍 معلومات التوصيل</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">الموقع</div>
                                <div class="info-value">${city} - ${area}</div>
                                ${address ? `<div style="margin-top: 5px; font-size: 14px; color: #718096;">${address}</div>` : ''}
                            </div>
                            <div class="info-item">
                                <div class="info-label">مواعيد التسليم</div>
                                <div style="margin-top: 5px;">
                                    <div style="margin-bottom: 8px;">
                                        <strong style="color: #2d3748;">التحميل:</strong><br>
                                        ${formatDate(supplierOrder.loadingDate)} - ${supplierOrder.loadingTime}
                                    </div>
                                    <div>
                                        <strong style="color: #2d3748;">الوصول المتوقع:</strong><br>
                                        ${formatDate(customerOrder.arrivalDate)} - ${customerOrder.arrivalTime}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    ${mergeNotes ? `
                    <div class="section">
                        <h2 class="section-title">📝 ملاحظات الدمج</h2>
                        <div style="background: #f0f9ff; padding: 20px; border-radius: 8px; border-right: 4px solid #1890ff;">
                            <p style="font-size: 15px; line-height: 1.6; color: #2c5282;">${mergeNotes}</p>
                        </div>
                    </div>
                    ` : ''}
                    
                    <div class="section">
                        <h2 class="section-title">👥 معلومات الجهات المعنية</h2>
                        <div class="info-grid">
                            <div class="info-item">
                                <div class="info-label">🏭 معلومات المورد</div>
                                <div style="margin-top: 8px; font-size: 14px; color: #4a5568;">
                                    <div><strong>الشخص المسؤول:</strong> ${supplierOrder.supplierContactPerson || 'غير محدد'}</div>
                                    ${supplierOrder.supplierPhone ? `<div><strong>📞 الهاتف:</strong> ${supplierOrder.supplierPhone}</div>` : ''}
                                    ${supplierOrder.supplier?.email ? `<div><strong>✉️ الإيميل:</strong> ${supplierOrder.supplier.email}</div>` : ''}
                                </div>
                            </div>
                            
                            <div class="info-item">
                                <div class="info-label">👤 معلومات العميل</div>
                                <div style="margin-top: 8px; font-size: 14px; color: #4a5568;">
                                    ${customerOrder.customerPhone ? `<div><strong>📞 الهاتف:</strong> ${customerOrder.customerPhone}</div>` : ''}
                                    ${customerOrder.customer?.email ? `<div><strong>✉️ الإيميل:</strong> ${customerOrder.customer.email}</div>` : ''}
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="section">
                        <h2 class="section-title">⏰ الجدول الزمني</h2>
                        <div class="timeline">
                            <div class="timeline-item">
                                <strong>وقت التحميل:</strong><br>
                                ${formatDate(supplierOrder.loadingDate)} - ${supplierOrder.loadingTime}
                            </div>
                            <div class="timeline-item">
                                <strong>وقت الوصول المتوقع:</strong><br>
                                ${formatDate(customerOrder.arrivalDate)} - ${customerOrder.arrivalTime}
                            </div>
                            <div class="timeline-item">
                                <strong>تاريخ إنشاء الطلب المدموج:</strong><br>
                                ${formatDate(new Date())} - ${new Date().toLocaleTimeString('ar-SA', {hour: '2-digit', minute:'2-digit'})}
                            </div>
                        </div>
                    </div>
                    
                    <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 30px 0; text-align: center; border: 2px dashed #cbd5e0;">
                        <p style="color: #4a5568; font-size: 15px;">
                            📊 <strong>تتبع الطلب:</strong> يمكنك تتبع حالة هذا الطلب المدموج عبر لوحة التحكم في النظام
                        </p>
                        <p style="color: #718096; font-size: 13px; margin-top: 10px;">
                            هذه عملية تلقائية، لا حاجة للرد على هذا البريد
                        </p>
                    </div>
                </div>
                
                <div class="footer">
                    <div class="logo">شركة البحيرة العربية نظام ادارة الطلبات</div>
                    <p>تم إرسال هذه الرسالة تلقائيًا إلى جميع المستخدمين المسجلين في النظام</p>
                   <p>📧 إجمالي المستلمين: <strong>${owners.length} Owner</strong></p>

                    <p>© ${new Date().getFullYear()} جميع الحقوق محفوظة</p>
                    <p style="font-size: 12px; opacity: 0.6; margin-top: 15px;">
                        هذا إشعار نظامي، يرجى عدم الرد على هذا البريد الإلكتروني
                    </p>
                </div>
            </div>
        </body>
        </html>
      `;
    };

    // =========================
    // 📧 إرسال البريد لجميع المستخدمين المسجلين
    // =========================
    let emailStats = {
      totalUsers: owners.length,
      sent: 0,
      failed: 0,
      failedEmails: []
    };

    try {
     if (owners.length > 0) {

        // تجميع جميع عناوين البريد
        const ownerEmails = owners
  .map(user => user.email)
  .filter(email => email && email.includes('@'));

        
        if (ownerEmails.length > 0) {
  const emailTemplate = createMergeEmailTemplate();

  await sendEmail({
    to: [], // بدون مستلم رئيسي
    bcc: ownerEmails, // ⭐ Owners فقط
    subject: `📊 إشعار دمج طلبات: ${supplierOrder.orderNumber} ↔ ${customerOrder.orderNumber}`,
    html: emailTemplate
  });

  emailStats.sent = ownerEmails.length;
  console.log(`✅ تم إرسال بريد الدمج إلى ${ownerEmails.length} Owner`);
} else {
  console.warn('⚠️ لا يوجد Owners لديهم بريد إلكتروني صالح');
}

      }

      // إرسال بريد إضافي للمورد والعميل (إن وجد)
      const additionalEmails = [];
      
      // بريد المورد
      if (supplierOrder.supplier?.email) {
        additionalEmails.push({
          email: supplierOrder.supplier.email,
          name: supplierOrder.supplierName,
          type: 'مورد'
        });
      }
      
      // بريد العميل
      if (customerOrder.customer?.email) {
        additionalEmails.push({
          email: customerOrder.customer.email,
          name: customerOrder.customerName,
          type: 'عميل'
        });
      }
      
      // إرسال بريد خاص للمورد والعميل
      for (const recipient of additionalEmails) {
        try {
          const personalizedTemplate = `
            <div dir="rtl" style="font-family: Arial; padding:20px">
              <h2>${recipient.type === 'مورد' ? '✅ تأكيد دمج طلبك' : '✅ تأكيد تخصيص مورد'}</h2>
              <p>عزيزي ${recipient.name},</p>
              <p>${recipient.type === 'مورد' 
                ? `تم دمج طلبك <strong>${supplierOrder.orderNumber}</strong> مع طلب العميل <strong>${customerOrder.orderNumber}</strong> بنجاح.` 
                : `تم تخصيص مورد لطلبك <strong>${customerOrder.orderNumber}</strong> بنجاح.`}</p>
              <div style="background:#f0f8ff; padding:15px; margin:15px 0; border-radius:8px">
                <p><strong>الطلب المدموج:</strong> ${mergedOrder.orderNumber}</p>
                <p><strong>${recipient.type === 'مورد' ? 'العميل' : 'المورد'}:</strong> ${recipient.type === 'مورد' ? customerOrder.customerName : supplierOrder.supplierName}</p>
                <p><strong>الكمية:</strong> ${customerQty} ${supplierOrder.unit || 'لتر'}</p>
                <p><strong>القيمة:</strong> ${formatCurrency(mergedOrder.totalPrice)}</p>
              </div>
              <p>تم إرسال إشعار عام لهذا الدمج إلى جميع المستخدمين المسجلين في النظام.</p>
            </div>
          `;
          
          await sendEmail({
            to: recipient.email,
            subject: recipient.type === 'مورد' 
              ? `✅ تم دمج طلبك ${supplierOrder.orderNumber} مع عميل` 
              : `✅ تم تخصيص مورد لطلبك ${customerOrder.orderNumber}`,
            html: personalizedTemplate
          });
          
          console.log(`📧 تم إرسال بريد إضافي إلى ${recipient.type}: ${recipient.email}`);
        } catch (error) {
          console.error(`❌ فشل إرسال بريد إضافي إلى ${recipient.type} ${recipient.email}:`, error.message);
        }
      }

    } catch (emailError) {
      console.error('❌ فشل إرسال بريد الدمج:', emailError.message);
      emailStats.failed = owners.length;

    }

    // =========================
    // ✅ تأكيد العملية
    // =========================
    await session.commitTransaction();
    session.endSession();

    try {
      await ownerOrderNotificationService.notifyOwnerOnMergedOrderCompletion({
        order: mergedOrder,
        oldStatus: 'تم الدمج',
        reason: mergeNotes,
        trigger: 'merge_orders',
        completedBy: req.user.name || req.user.email || 'النظام',
      });
    } catch (ownerNotifyError) {
      console.error('❌ Failed owner completion notification (merge):', ownerNotifyError.message);
    }

    // =========================
    // 📊 الاستجابة
    // =========================
    return res.status(200).json({
      success: true,
      message: `تم دمج الطلبات بنجاح وإرسال الإشعار إلى ${emailStats.sent} Owner`,
      data: {
        mergedOrder: {
          _id: mergedOrder._id,
          orderNumber: mergedOrder.orderNumber,
          status: mergedOrder.status,
          mergeStatus: mergedOrder.mergeStatus,
          supplierName: mergedOrder.supplierName,
          customerName: mergedOrder.customerName,
          quantity: mergedOrder.quantity,
          unit: mergedOrder.unit,
          fuelType: mergedOrder.fuelType,
          totalPrice: mergedOrder.totalPrice,
          createdAt: mergedOrder.createdAt
        },
        emailStats: {
          totalUsers: emailStats.totalUsers,
          emailsSent: emailStats.sent,
          emailsFailed: emailStats.failed,
          sentToAllUsers: emailStats.sent > 0,
          percentage: emailStats.totalUsers > 0 ? Math.round((emailStats.sent / emailStats.totalUsers) * 100) : 0
        },
        timestamp: new Date().toISOString(),
        mergeDetails: {
          supplierOrder: supplierOrder.orderNumber,
          customerOrder: customerOrder.orderNumber,
          mergedOrder: mergedOrder.orderNumber,
          mergedBy: req.user.name || req.user.email
        }
      }
    });

  } catch (error) {
    // =========================
    // ❌ معالجة الأخطاء
    // =========================
    await session.abortTransaction();
    session.endSession();
    
    console.error('❌ Error merging orders:', error);
    
    return res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء دمج الطلبات',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

exports.dispatchMovementOrder = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    if (!['movement', 'owner', 'admin'].includes(req.user?.role)) {
      await session.abortTransaction();
      session.endSession();
      return res.status(403).json({
        success: false,
        message: 'غير مسموح باستخدام توجيه طلبات الحركة',
      });
    }

    const {
      customerId,
      customerRequestDate,
      expectedArrivalDate,
      driverId,
      requestType,
    } = req.body || {};

    if (!customerId || !customerRequestDate || !expectedArrivalDate) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'العميل وتاريخ طلب العميل وتاريخ الوصول مطلوبة',
      });
    }

    const normalizedRequestType = ['شراء', 'نقل'].includes(requestType)
      ? requestType
      : 'شراء';

    const requestDate = new Date(customerRequestDate);
    const arrivalDate = new Date(expectedArrivalDate);
    if (Number.isNaN(requestDate.getTime()) || Number.isNaN(arrivalDate.getTime())) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'تواريخ التوجيه غير صالحة',
      });
    }

    const supplierOrder = await Order.findById(req.params.id)
      .populate('supplier', 'name company contactPerson phone email address')
      .session(session);

    if (!supplierOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({
        success: false,
        message: 'طلب الحركة غير موجود',
      });
    }

    if (
      supplierOrder.orderSource !== 'مورد' ||
      supplierOrder.entryChannel !== 'movement'
    ) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'الطلب المحدد ليس طلب حركة صالح للتوجيه',
      });
    }

    const previousMovementCustomerId = toIdString(supplierOrder.movementCustomer);
    const previousMovementCustomerName = String(supplierOrder.movementCustomerName || '').trim();

    const customerDoc = await Customer.findById(customerId).session(session);
    if (!customerDoc) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({
        success: false,
        message: 'العميل المحدد غير موجود',
      });
    }

    if (driverId) {
      const driverDoc = await Driver.findById(driverId).session(session);
      if (!driverDoc) {
        await session.abortTransaction();
        session.endSession();
        return res.status(404).json({
          success: false,
          message: 'السائق المحدد غير موجود',
        });
      }

      supplierOrder.driver = driverDoc._id;
      supplierOrder.driverName = driverDoc.name;
      supplierOrder.driverPhone = driverDoc.phone;
      supplierOrder.vehicleNumber = driverDoc.vehicleNumber;
    }

    if (!supplierOrder.driver && !supplierOrder.driverName) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'يجب اختيار السائق أولاً قبل توجيه الطلب',
      });
    }

    let customerOrder = null;
    let mergedOrder = null;

    if (supplierOrder.movementCustomerOrderId) {
      customerOrder = await Order.findById(supplierOrder.movementCustomerOrderId).session(session);
    }

    if (!customerOrder && supplierOrder.movementMergedOrderId) {
      customerOrder = await Order.findOne({
        mergedWithOrderId: supplierOrder.movementMergedOrderId,
        orderSource: 'عميل',
      }).session(session);
    }

    if (supplierOrder.movementMergedOrderId) {
      mergedOrder = await Order.findById(supplierOrder.movementMergedOrderId).session(session);
    }

    if (!mergedOrder && supplierOrder.mergedWithOrderId) {
      mergedOrder = await Order.findById(supplierOrder.mergedWithOrderId).session(session);
    }

    if (!customerOrder) {
      customerOrder = await buildMovementCustomerOrder({
        session,
        supplierOrder,
        customerDoc,
        user: req.user,
        customerRequestDate: requestDate,
        expectedArrivalDate: arrivalDate,
        requestType: normalizedRequestType,
      });
    } else {
      customerOrder.entryChannel = 'movement';
      customerOrder.customer = customerDoc._id;
      customerOrder.customerName = customerDoc.name;
      customerOrder.customerCode = customerDoc.code;
      customerOrder.customerPhone = customerDoc.phone;
      customerOrder.customerEmail = customerDoc.email;
      customerOrder.customerAddress = customerDoc.address;
      customerOrder.requestType = normalizedRequestType;
      customerOrder.supplier = supplierOrder.supplier?._id || supplierOrder.supplier;
      customerOrder.supplierName = supplierOrder.supplierName;
      customerOrder.supplierPhone = supplierOrder.supplierPhone;
      customerOrder.supplierCompany = supplierOrder.supplierCompany;
      customerOrder.supplierContactPerson = supplierOrder.supplierContactPerson;
      customerOrder.supplierAddress = supplierOrder.supplierAddress;
      customerOrder.supplierOrderNumber = supplierOrder.supplierOrderNumber;
      customerOrder.productType = supplierOrder.productType;
      customerOrder.fuelType = supplierOrder.fuelType;
      customerOrder.quantity = supplierOrder.quantity;
      customerOrder.unit = supplierOrder.unit || 'لتر';
      customerOrder.city = customerDoc.city || supplierOrder.city || 'غير محدد';
      customerOrder.area = customerDoc.area || supplierOrder.area || 'غير محدد';
      customerOrder.address =
        customerDoc.address ||
        supplierOrder.address ||
        `${customerDoc.city || supplierOrder.city || 'غير محدد'} - ${customerDoc.area || supplierOrder.area || 'غير محدد'}`;
      customerOrder.orderDate = requestDate;
      customerOrder.loadingDate = supplierOrder.loadingDate || requestDate;
      customerOrder.loadingTime = supplierOrder.loadingTime || '08:00';
      customerOrder.arrivalDate = arrivalDate;
      customerOrder.arrivalTime = supplierOrder.arrivalTime || '10:00';
      customerOrder.updatedAt = new Date();
      await customerOrder.save({ session });
    }

    if (!mergedOrder) {
      mergedOrder = await createMergedOrderFromSourceOrders({
        session,
        supplierOrder,
        customerOrder,
        user: req.user,
        mergeNotes: `تم توجيه طلب الحركة ${supplierOrder.orderNumber}`,
      });
    } else {
      applyMergedOrderSnapshot(
        mergedOrder,
        supplierOrder,
        customerOrder,
        req.user,
        `تم تحديث توجيه طلب الحركة ${supplierOrder.orderNumber}`,
      );
      linkSourceOrderToMerged(supplierOrder, customerOrder, mergedOrder, req.user);
      linkSourceOrderToMerged(customerOrder, supplierOrder, mergedOrder, req.user);
      await mergedOrder.save({ session });
      await customerOrder.save({ session });
    }

    applyMovementDispatchMetadata(
      supplierOrder,
      customerOrder,
      mergedOrder,
      req.user,
      requestDate,
      arrivalDate,
    );

    const nextMovementCustomerId = toIdString(customerDoc._id);
    const customerChanged =
      previousMovementCustomerId &&
      nextMovementCustomerId &&
      previousMovementCustomerId !== nextMovementCustomerId;

    if (customerChanged) {
      appendOrderNote(
        supplierOrder,
        `تم تبديل العميل للطلب من ${previousMovementCustomerName || 'غير محدد'} إلى ${customerDoc.name}`,
      );
    }
    appendOrderNote(
      supplierOrder,
      `تم توجيه طلب الحركة إلى العميل ${customerDoc.name} مع السائق ${supplierOrder.driverName || 'غير محدد'}`,
    );
    await supplierOrder.save({ session });

    await new Activity({
      orderId: supplierOrder._id,
      activityType: customerChanged ? 'تعديل التوجيه' : supplierOrder.isNew ? 'إنشاء' : 'توجيه',
      description: customerChanged
        ? `تم تبديل عميل طلب الحركة ${supplierOrder.orderNumber} من ${previousMovementCustomerName || 'غير محدد'} إلى ${customerDoc.name}`
        : `تم توجيه طلب الحركة ${supplierOrder.orderNumber} إلى العميل ${customerDoc.name}`,
      details: {
        customerName: customerDoc.name,
        ...(customerChanged
          ? {
              previousCustomerId: previousMovementCustomerId,
              previousCustomerName: previousMovementCustomerName || null,
            }
          : {}),
        driverName: supplierOrder.driverName,
        mergedOrderNumber: mergedOrder.orderNumber,
      },
      performedBy: req.user._id,
      performedByName: req.user.name || req.user.email,
    }).save({ session });

    await session.commitTransaction();
    session.endSession();

    const populateSpec = [
      { path: 'customer', select: 'name code phone email city area address' },
      { path: 'supplier', select: 'name company contactPerson phone email address' },
      { path: 'driver', select: 'name phone vehicleNumber' },
      { path: 'createdBy', select: 'name email role' },
    ];

    const [supplierOrderView, customerOrderView, mergedOrderView] = await Promise.all([
      Order.findById(supplierOrder._id).populate(populateSpec),
      Order.findById(customerOrder._id).populate(populateSpec),
      Order.findById(mergedOrder._id).populate(populateSpec),
    ]);

    // Send WhatsApp update to driver (best effort)
    try {
      await WhatsAppService.sendOrderToDriver({
        order: {
          ...supplierOrderView.toObject(),
          customerName: customerOrderView.customerName || customerDoc.name,
        },
        extraLines: [
          `تم توجيه الطلب إلى العميل: ${customerOrderView.customerName || customerDoc.name}`,
        ],
      });
    } catch (whatsError) {
      console.warn('⚠️ WhatsApp dispatch message failed:', whatsError.message);
    }

    // Notify driver (push + email) about dispatch / customer change (best effort)
    try {
      const driverIdForNotification = toIdString(
        supplierOrderView?.driver?._id || supplierOrderView?.driver,
      );
      if (driverIdForNotification) {
        const recipients = await findDriverRecipients(driverIdForNotification);
        if (recipients.length) {
          const nextCustomerName =
            customerOrderView.customerName || customerDoc.name;
          const nextCustomerId = toIdString(supplierOrderView.movementCustomer);
          const isCustomerChanged =
            previousMovementCustomerId &&
            nextCustomerId &&
            previousMovementCustomerId !== nextCustomerId;

          const title = isCustomerChanged
            ? 'تم تبديل العميل'
            : 'تم توجيه الطلب إلى العميل';
          const message = isCustomerChanged
            ? `تم تبديل العميل للطلب ${supplierOrderView.orderNumber} من ${previousMovementCustomerName || 'غير محدد'} إلى ${nextCustomerName}`
            : `تم توجيه الطلب ${supplierOrderView.orderNumber} إلى العميل ${nextCustomerName}`;

          await NotificationService.send({
            type: 'movement_dispatched',
            title,
            message,
            data: {
              event: isCustomerChanged ? 'movement_customer_changed' : 'movement_dispatched',
              orderId: String(supplierOrderView._id || ''),
              orderNumber: supplierOrderView.orderNumber || '',
              movementCustomerId: nextCustomerId || '',
              movementCustomerName: nextCustomerName || '',
              previousCustomerId: previousMovementCustomerId || '',
              previousCustomerName: previousMovementCustomerName || '',
              status: supplierOrderView.status || '',
              driverId: driverIdForNotification,
            },
            recipients,
            priority: 'high',
            createdBy: req.user?._id,
            orderId: supplierOrderView._id,
            channels: ['in_app', 'push', 'email'],
          });
        }
      }
    } catch (notifyError) {
      console.warn('⚠️ Driver dispatch notification failed:', notifyError.message);
    }

    return res.status(200).json({
      success: true,
      message: 'تم توجيه طلب الحركة بنجاح',
      data: {
        supplierOrder: supplierOrderView,
        customerOrder: customerOrderView,
        mergedOrder: mergedOrderView,
      },
    });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();

    console.error('Error dispatching movement order:', error);
    return res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء توجيه طلب الحركة',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

exports.sendOrderToDriverWhatsapp = async (req, res) => {
  try {
    if (!['movement', 'owner', 'admin'].includes(req.user?.role)) {
      return res.status(403).json({
        success: false,
        message: 'غير مسموح بإرسال واتساب للطلب',
      });
    }

    const order = await Order.findById(req.params.id)
      .populate('supplier', 'name company contactPerson phone email address')
      .populate('customer', 'name code phone email city area address')
      .populate('driver', 'name phone vehicleNumber');

    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'الطلب غير موجود',
      });
    }

    if (!order.driver && !order.driverPhone) {
      return res.status(400).json({
        success: false,
        message: 'يجب اختيار سائق قبل إرسال الواتساب',
      });
    }

    await WhatsAppService.sendOrderToDriver({ order: order.toObject() });

    return res.status(200).json({
      success: true,
      message: 'تم إرسال الواتساب للسائق',
    });
  } catch (error) {
    console.error('❌ Error sending WhatsApp to driver:', error);
    return res.status(500).json({
      success: false,
      message: 'فشل في إرسال الواتساب للسائق',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

exports.updateMergedOrderLinks = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { supplierOrderId, customerOrderId, mergeNotes } = req.body || {};

    if (!supplierOrderId || !customerOrderId) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'معرف طلب المورد ومعرف طلب العميل مطلوبان',
      });
    }

    const mergedOrder = await Order.findById(req.params.id).session(session);

    if (!mergedOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({
        success: false,
        message: 'الطلب المدمج غير موجود',
      });
    }

    if (mergedOrder.orderSource !== 'مدمج') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'الطلب المحدد ليس طلبًا مدمجًا',
      });
    }

    if (mergedOrder.status == 'ملغى') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'لا يمكن تعديل طلب مدمج ملغي',
      });
    }

    const [currentSupplierOrder, currentCustomerOrder] = await Promise.all([
      Order.findOne({ mergedWithOrderId: mergedOrder._id, orderSource: 'مورد' })
        .session(session),
      Order.findOne({ mergedWithOrderId: mergedOrder._id, orderSource: 'عميل' })
        .session(session),
    ]);

    if (!currentSupplierOrder || !currentCustomerOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'تعذر العثور على الطلبين المرتبطين بهذا الطلب المدمج',
      });
    }

    const [nextSupplierOrder, nextCustomerOrder] = await Promise.all([
      Order.findById(supplierOrderId)
        .populate('supplier', 'name company contactPerson phone email address')
        .populate('createdBy', 'name email')
        .session(session),
      Order.findById(customerOrderId)
        .populate('customer', 'name code phone email city area address')
        .populate('createdBy', 'name email')
        .session(session),
    ]);

    if (!nextSupplierOrder || !nextCustomerOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({
        success: false,
        message: 'أحد الطلبات المختارة غير موجود',
      });
    }

    if (nextSupplierOrder.orderSource !== 'مورد') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'الطلب المختار للمورد غير صحيح',
      });
    }

    if (nextCustomerOrder.orderSource !== 'عميل') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'الطلب المختار للعميل غير صحيح',
      });
    }

    if (
      !idsEqual(nextSupplierOrder._id, currentSupplierOrder._id) &&
      nextSupplierOrder.mergeStatus !== 'منفصل'
    ) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'طلب المورد المختار مرتبط مسبقًا بطلب آخر',
      });
    }

    if (
      !idsEqual(nextCustomerOrder._id, currentCustomerOrder._id) &&
      nextCustomerOrder.mergeStatus !== 'منفصل'
    ) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'طلب العميل المختار مرتبط مسبقًا بطلب آخر',
      });
    }

    if (nextSupplierOrder.fuelType !== nextCustomerOrder.fuelType) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'نوع الوقود غير متطابق بين الطلبين',
      });
    }

    const supplierQty = Number(nextSupplierOrder.quantity || 0);
    const customerQty = Number(nextCustomerOrder.quantity || 0);

    if (supplierQty < customerQty) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'كمية طلب المورد أقل من كمية طلب العميل',
      });
    }

    const releasedOrders = [];

    if (!idsEqual(currentSupplierOrder._id, nextSupplierOrder._id)) {
      restoreSeparatedOrder(
        currentSupplierOrder,
        `تم فصل الطلب من الطلب المدمج ${mergedOrder.orderNumber}`,
      );
      await currentSupplierOrder.save({ session });
      releasedOrders.push(currentSupplierOrder);
    }

    if (!idsEqual(currentCustomerOrder._id, nextCustomerOrder._id)) {
      restoreSeparatedOrder(
        currentCustomerOrder,
        `تم فصل الطلب من الطلب المدمج ${mergedOrder.orderNumber}`,
      );
      await currentCustomerOrder.save({ session });
      releasedOrders.push(currentCustomerOrder);
    }

    applyMergedOrderSnapshot(
      mergedOrder,
      nextSupplierOrder,
      nextCustomerOrder,
      req.user,
      mergeNotes,
    );
    linkSourceOrderToMerged(
      nextSupplierOrder,
      nextCustomerOrder,
      mergedOrder,
      req.user,
    );
    linkSourceOrderToMerged(
      nextCustomerOrder,
      nextSupplierOrder,
      mergedOrder,
      req.user,
    );

    await nextSupplierOrder.save({ session });
    await nextCustomerOrder.save({ session });
    await mergedOrder.save({ session });

    const activity = new Activity({
      orderId: mergedOrder._id,
      activityType: 'تعديل دمج',
      description: `تم تحديث ربط الطلب المدمج ${mergedOrder.orderNumber}`,
      details: {
        previousSupplierOrder: currentSupplierOrder.orderNumber,
        previousCustomerOrder: currentCustomerOrder.orderNumber,
        supplierOrder: nextSupplierOrder.orderNumber,
        customerOrder: nextCustomerOrder.orderNumber,
        updatedBy: req.user.name || req.user.email,
      },
      performedBy: req.user._id,
      performedByName: req.user.name || req.user.email,
    });
    await activity.save({ session });

    await session.commitTransaction();
    session.endSession();

    return res.status(200).json({
      success: true,
      message: 'تم تحديث الطلب المدمج بنجاح',
      data: {
        mergedOrder,
        supplierOrder: nextSupplierOrder,
        customerOrder: nextCustomerOrder,
        releasedOrders,
      },
    });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();

    console.error('Error updating merged order links:', error);

    return res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء تحديث الطلب المدمج',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

exports.unmergeOrder = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const mergedOrder = await Order.findById(req.params.id).session(session);

    if (!mergedOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({
        success: false,
        message: 'الطلب المدمج غير موجود',
      });
    }

    if (mergedOrder.orderSource !== 'مدمج') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'الطلب المحدد ليس طلبًا مدمجًا',
      });
    }

    if (mergedOrder.status === 'ملغى') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'تم إلغاء الطلب المدمج مسبقًا',
      });
    }

    const [supplierOrder, customerOrder] = await Promise.all([
      Order.findOne({ mergedWithOrderId: mergedOrder._id, orderSource: 'مورد' })
        .session(session),
      Order.findOne({ mergedWithOrderId: mergedOrder._id, orderSource: 'عميل' })
        .session(session),
    ]);

    if (!supplierOrder && !customerOrder) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({
        success: false,
        message: 'لا توجد طلبات مرتبطة يمكن فصلها عن هذا الطلب المدمج',
      });
    }

    if (supplierOrder) {
      restoreSeparatedOrder(
        supplierOrder,
        `تم إلغاء الربط مع الطلب المدمج ${mergedOrder.orderNumber}`,
      );
      await supplierOrder.save({ session });
    }

    if (customerOrder) {
      restoreSeparatedOrder(
        customerOrder,
        `تم إلغاء الربط مع الطلب المدمج ${mergedOrder.orderNumber}`,
      );
      await customerOrder.save({ session });
    }

    mergedOrder.status = 'ملغى';
    mergedOrder.mergeStatus = 'منفصل';
    mergedOrder.cancelledAt = new Date();
    mergedOrder.cancellationReason =
      req.body?.reason || 'تم إلغاء الطلب المدمج';
    mergedOrder.completedAt = null;
    mergedOrder.updatedAt = new Date();
    appendOrderNote(
      mergedOrder,
      `تم إلغاء الطلب المدمج وفصل الطلبات المرتبطة بواسطة ${req.user.name || req.user.email}`,
    );

    await mergedOrder.save({ session });

    const mergedActivity = new Activity({
      orderId: mergedOrder._id,
      activityType: 'فك دمج',
      description: `تم إلغاء الطلب المدمج ${mergedOrder.orderNumber}`,
      details: {
        supplierOrder: supplierOrder?.orderNumber,
        customerOrder: customerOrder?.orderNumber,
        cancelledBy: req.user.name || req.user.email,
      },
      performedBy: req.user._id,
      performedByName: req.user.name || req.user.email,
    });
    await mergedActivity.save({ session });

    await session.commitTransaction();
    session.endSession();

    return res.status(200).json({
      success: true,
      message: 'تم إلغاء الطلب المدمج وإعادة الطلبات إلى الحالة المنفصلة',
      data: {
        mergedOrder,
        supplierOrder,
        customerOrder,
      },
    });
  } catch (error) {
    await session.abortTransaction();
    session.endSession();

    console.error('Error unmerging order:', error);

    return res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء فك الطلب المدمج',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

// دالة مساعدة لتنسيق العملة
function formatCurrency(amount) {
  if (!amount) return '0.00 ريال';
  return amount.toLocaleString('ar-SA', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }) + ' ريال';
}


// ============================================
// 🗑️ حذف الطلب
// ============================================

exports.deleteOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('customer', 'name email')
      .populate('supplier', 'name email contactPerson')
      .populate('createdBy', 'name email');

    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    // السماح فقط للإداريين بالحذف
    if (req.user.role !== 'admin' && req.user.role !== 'owner') {
      return res.status(403).json({ error: 'غير مصرح بحذف الطلب' });
    }

    // التحقق من حالة الدمج
    if (order.mergeStatus === 'مدمج') {
      return res.status(400).json({ 
        error: 'لا يمكن حذف طلب مدمج. الرجاء فك الدمج أولاً.' 
      });
    }

    // إرسال إيميل قبل الحذف
    try {
      const emails = await getOrderEmails(order);

      if (!emails || emails.length === 0) {
        console.log(`⚠️ No valid emails for order deletion - order ${order.orderNumber}`);
      } else {
        await sendEmail({
          to: emails,
          subject: `🗑️ تم حذف الطلب ${order.orderNumber}`,
          html: EmailTemplates.orderDeletedTemplate(order, req.user.name),
        });
      }
    } catch (emailError) {
      console.error('❌ Failed to send delete order email:', emailError.message);
    }

    const deleteFile = (filePath) => {
      if (isRemoteFilePath(filePath)) {
        return;
      }
      if (fs.existsSync(filePath)) {
        try {
          fs.unlinkSync(filePath);
        } catch (err) {
          console.error(`Failed to delete file: ${filePath}`, err);
        }
      }
    };

    order.attachments.forEach((attachment) => {
      deleteFile(attachment.path);
    });

    order.supplierDocuments.forEach((doc) => {
      deleteFile(doc.path);
    });

    order.customerDocuments.forEach((doc) => {
      deleteFile(doc.path);
    });

    const activity = new Activity({
      orderId: order._id,
      activityType: 'حذف',
      description: `تم حذف الطلب رقم ${order.orderNumber}`,
      performedBy: req.user._id,
      performedByName: req.user.name,
      changes: {
        'رقم الطلب': order.orderNumber,
        'نوع الطلب': order.orderSource === 'عميل' ? 'طلب عميل' : 'طلب مورد',
        'العميل': order.customerName,
        'المورد': order.supplierName,
      },
    });
    await activity.save();

    await Order.findByIdAndDelete(req.params.id);

    return res.json({
      message: 'تم حذف الطلب بنجاح',
      orderNumber: order.orderNumber
    });
  } catch (error) {
    console.error('Error deleting order:', error);
    return res.status(500).json({ error: 'حدث خطأ في حذف الطلب' });
  }
};



exports.deleteAttachment = async (req, res) => {
  try {
    const { orderId, attachmentId, docType } = req.params;

    const order = await Order.findById(orderId)
      .populate('customer', 'name email')
      .populate('createdBy', 'name email');

    if (!order) {
      return res.status(404).json({ error: 'الطلب غير موجود' });
    }

    let attachment = null;
    let collection = null;

    if (docType === 'supplier') {
      collection = order.supplierDocuments;
    } else if (docType === 'customer') {
      collection = order.customerDocuments;
    } else {
      collection = order.attachments;
    }

    attachment = collection.id(attachmentId);
    
    if (!attachment) {
      return res.status(404).json({ error: 'الملف غير موجود' });
    }

    try {
      const emails = await getOrderEmails(order);

      if (!emails || emails.length === 0) {
        console.log(`⚠️ No valid emails for attachment deletion - order ${order.orderNumber}`);
      } else {
        await sendEmail({
          to: emails,
          subject: `📎 حذف مرفق من الطلب ${order.orderNumber}`,
          html: EmailTemplates.attachmentDeletedTemplate(order, attachment.filename, req.user.name, docType),
        });
      }
    } catch (emailError) {
      console.error('❌ Failed to send attachment delete email:', emailError.message);
    }


    if (!isRemoteFilePath(attachment.path) && fs.existsSync(attachment.path)) {
      fs.unlinkSync(attachment.path);
    }


    collection.pull(attachmentId);
    await order.save();


    const activity = new Activity({
      orderId: order._id,
      activityType: 'حذف',
      description: `تم حذف مرفق من الطلب رقم ${order.orderNumber}`,
      performedBy: req.user._id,
      performedByName: req.user.name,
      changes: {
        'اسم الملف': attachment.filename,
        'نوع الملف': docType === 'supplier' ? 'مستند مورد' : docType === 'customer' ? 'مستند عميل' : 'مرفق عام'
      },
    });
    await activity.save();

    return res.json({
      message: 'تم حذف الملف بنجاح',
      fileName: attachment.filename,
      docType
    });
  } catch (error) {
    console.error('Error deleting attachment:', error);
    return res.status(500).json({ error: 'حدث خطأ في حذف الملف' });
  }
};



const { safeSendEmail } = require('../services/emailQueue');

exports.checkArrivalNotifications = async () => {
  try {
    const now = new Date();

    const orders = await Order.find({
      status: { $in: ['جاهز للتحميل', 'في انتظار التحميل', 'مخصص للعميل', 'في الطريق'] },
      arrivalNotificationSentAt: { $exists: false },
    })
      .populate('customer', 'name email')
      .populate('supplier', 'name email contactPerson')
      .populate('createdBy', 'name email');

    if (!orders.length) {
      return;
    }

    const User = require('../models/User');
    const Notification = require('../models/Notification');


    const adminUsers = await User.find({
      role: { $in: ['admin', 'owner'] },
      isActive: true,
    });

    for (const order of orders) {
      try {
        const notificationTime = order.getArrivalNotificationTime();

        if (now < notificationTime) {
          continue;
        }

        if (adminUsers.length > 0) {
          const notification = new Notification({
            type: 'arrival_reminder',
            title: 'تذكير بقرب وقت الوصول',
            message: `الطلب رقم ${order.orderNumber} (${order.customerName}) سيصل خلال ساعتين ونصف`,
            data: {
              orderId: order._id,
              orderNumber: order.orderNumber,
              customerName: order.customerName,
              expectedArrival: `${order.arrivalDate.toLocaleDateString('ar-SA')} ${order.arrivalTime}`,
              supplierName: order.supplierName,
              auto: true,
            },
            recipients: adminUsers.map((user) => ({ user: user._id })),
            createdBy: order.createdBy?._id,
          });

          await notification.save();
        }


        try {
          const arrivalDateTime = order.getFullArrivalDateTime();
          const timeRemainingMs = arrivalDateTime - now;
          const timeRemaining = formatDuration(timeRemainingMs);

          const emails = await getOrderEmails(order);

          if (emails && emails.length > 0) {
            await safeSendEmail(() =>
              sendEmail({
                to: emails,
                subject: `⏰ تذكير بوصول الطلب ${order.orderNumber}`,
                html: EmailTemplates.arrivalReminderTemplate(order, timeRemaining),
              })
            );
          } else {
            console.log(`⚠️ No valid emails for arrival reminder - order ${order.orderNumber}`);
          }
        } catch (emailError) {
          console.error(
            `❌ Email failed for order ${order.orderNumber}:`,
            emailError.message
          );
        }


        order.arrivalNotificationSentAt = new Date();
        order.arrivalEmailSentAt = new Date();
        await order.save();

        console.log(
          `🔔📧 Arrival notification + email sent for order ${order.orderNumber}`
        );
      } catch (orderError) {
        console.error(
          `❌ Error processing arrival notification for order ${order.orderNumber}:`,
          orderError.message
        );
      }
    }
  } catch (error) {
    console.error('❌ خطأ في التحقق من إشعارات الوصول:', error);
  }
};


async function finalizeMergedOrder(order, options = {}) {
  const reasonLabel = options.reasonLabel || 'بعد انتهاء وقت التحميل';
  const logPrefix = options.logPrefix || 'Auto executed merged order';

  if (!order || order.status === 'تم التنفيذ') {
    return false;
  }

  const now = new Date();
  const oldStatus = order.status;

  order.status = 'تم التنفيذ';
  order.mergeStatus = 'مكتمل';
  order.completedAt = now;
  order.updatedAt = now;

  await order.save();

  console.log(
    `✅ ${logPrefix} ${order.orderNumber} من "${oldStatus}" إلى "تم التنفيذ"`
  );

  try {
    await ownerOrderNotificationService.notifyOwnerOnMergedOrderCompletion({
      order,
      oldStatus,
      reason: reasonLabel,
      trigger: 'auto_finalize',
      completedBy: 'النظام',
    });
  } catch (ownerNotifyError) {
    console.error('❌ Failed owner completion notification (auto finalize):', ownerNotifyError.message);
  }

  await Activity.create({
    orderId: order._id,
    activityType: 'تغيير حالة',
    description: `تم تنفيذ الطلب تلقائيًا ${reasonLabel} (طلب مدمج)`,
    performedBy: null,
    performedByName: 'النظام',
    changes: {
      الحالة: `من: ${oldStatus} → إلى: تم التنفيذ`
    }
  });

  try {
    const emails = await getOrderEmails(order);
    if (emails && emails.length) {
      await sendEmail({
        to: emails,
        subject: `✅ تم تنفيذ الطلب ${order.orderNumber}`,
        html: EmailTemplates.orderStatusTemplate(
          order,
          oldStatus,
          'تم التنفيذ',
          'النظام'
        )
      });
    }
  } catch (e) {
    console.error(`❌ Email failed for ${order.orderNumber}`, e.message);
  }

  return true;
}


exports.checkCompletedLoading = async () => {
  try {
    const now = new Date();

    const orders = await Order.find({
      // orderSource: 'مدمج',
      status: {
        $in: [
          'تم الدمج',
          'مخصص للعميل',
          'جاهز للتحميل',
          'في انتظار التحميل',
          'تم التحميل',
          'في الطريق',
          'تم التسليم'
        ]
      },
      completedAt: { $exists: false }
    })
      .populate('customer', 'name email')
      .populate('supplier', 'name email')
      .populate('createdBy', 'name email');

    if (!orders.length) return;

    for (const order of orders) {
      if (typeof order.getFullArrivalDateTime !== 'function') continue;

      const arrivalDateTime = order.getFullArrivalDateTime();
      if (!arrivalDateTime) continue;
      if (now < arrivalDateTime) continue;

      await finalizeMergedOrder(order, {
        reasonLabel: 'بعد انتهاء وقت التحميل',
        logPrefix: 'Auto executed merged order (arrival timer)'
      });
    }
  } catch (error) {
    console.error('❌ Error in checkCompletedLoading:', error);
  }
};

exports.autoExecuteMergedOrders = async () => {
  try {
    const now = new Date();
    const threshold = new Date(now.getTime() - 2 * 60 * 60 * 1000);

    const orders = await Order.find({
      // orderSource: 'مدمج',
      status: 'تم الدمج',
      completedAt: { $exists: false }
    })
      .populate('customer', 'name email')
      .populate('supplier', 'name email')
      .populate('createdBy', 'name email');

    if (!orders.length) return;

    for (const order of orders) {
      const mergedAtSource =
        order.mergedWithInfo?.mergedAt || order.mergedAt || order.createdAt;
      if (!mergedAtSource) continue;

      const mergedAt = new Date(mergedAtSource);
      if (isNaN(mergedAt.getTime())) continue;
      if (mergedAt > threshold) continue;

      await finalizeMergedOrder(order, {
        reasonLabel: 'بعد مرور ساعتين على الدمج',
        logPrefix: 'Auto executed merged order (merge timer)'
      });
    }
  } catch (error) {
    console.error('❌ Error in autoExecuteMergedOrders:', error);
  }
};

exports.checkInactiveCustomersWeekly = async () => {
  try {
    const User = require('../models/User');
    const now = new Date();
    const inactiveThreshold = new Date(now.getTime() - INACTIVITY_ALERT_INTERVAL_MS);

    const recipients = await User.find({
      role: { $in: ['admin', 'owner'] },
      isBlocked: { $ne: true },
      email: { $exists: true, $nin: [null, ''] },
    }).select('email');

    const recipientEmails = [...new Set(
      recipients
        .map((user) => String(user.email || '').trim().toLowerCase())
        .filter(Boolean)
    )];

    if (!recipientEmails.length) {
      console.log('No admin/owner recipients for inactivity alerts');
      return;
    }

    const customers = await Customer.find({
      isActive: true,
    }).select('_id name code lastInactivityAlertSentAt');

    if (!customers.length) {
      return;
    }

    const orderSummaries = await Order.aggregate([
      {
        $match: {
          customer: { $exists: true, $ne: null },
        },
      },
      { $sort: { orderDate: 1, createdAt: 1 } },
      {
        $group: {
          _id: '$customer',
          firstOrderDate: { $first: '$orderDate' },
          firstOrderNumber: { $first: '$orderNumber' },
          lastOrderDate: { $last: '$orderDate' },
          lastOrderNumber: { $last: '$orderNumber' },
          lastProductType: { $last: '$productType' },
          lastFuelType: { $last: '$fuelType' },
          lastQuantity: { $last: '$quantity' },
          lastUnit: { $last: '$unit' },
          lastTotalPrice: { $last: '$totalPrice' },
          ordersCount: { $sum: 1 },
        },
      },
    ]);

    const orderSummaryByCustomer = new Map(
      orderSummaries.map((summary) => [String(summary._id), summary])
    );

    let sentCount = 0;

    for (const customer of customers) {
      try {
        const summary = orderSummaryByCustomer.get(String(customer._id));
        const firstOrderDate = summary?.firstOrderDate
          ? new Date(summary.firstOrderDate)
          : null;
        const lastOrderDate = summary?.lastOrderDate
          ? new Date(summary.lastOrderDate)
          : null;

        const isInactive = !lastOrderDate || lastOrderDate <= inactiveThreshold;
        if (!isInactive) {
          continue;
        }

        const lastAlertAt = customer.lastInactivityAlertSentAt
          ? new Date(customer.lastInactivityAlertSentAt)
          : null;
        const shouldSendAlert =
          !lastAlertAt || now.getTime() - lastAlertAt.getTime() >= INACTIVITY_ALERT_INTERVAL_MS;

        if (!shouldSendAlert) {
          continue;
        }

        const historyDurationMs =
          firstOrderDate && lastOrderDate
            ? Math.max(lastOrderDate.getTime() - firstOrderDate.getTime(), 0)
            : 0;
        const historyDurationText =
          firstOrderDate && lastOrderDate
            ? formatDuration(historyDurationMs)
            : 'غير متاح';
        const inactivityMs = lastOrderDate
          ? Math.max(now.getTime() - lastOrderDate.getTime(), 0)
          : INACTIVITY_ALERT_INTERVAL_MS;
        const inactivityText = formatDuration(inactivityMs);
        const historyRangeText =
          firstOrderDate && lastOrderDate
            ? `${formatDateForEmail(firstOrderDate)} إلى ${formatDateForEmail(lastOrderDate)}`
            : 'لا يوجد سجل طلبات';

        await safeSendEmail(() =>
          sendEmail({
            bcc: recipientEmails,
            subject: `تنبيه خمول عميل - ${customer.name || 'عميل'}`,
            html: buildInactiveCustomerEmailTemplate({
              customer,
              summary,
              firstOrderDate,
              lastOrderDate,
              historyRangeText,
              historyDurationText,
              inactivityText,
            }),
          })
        );

        customer.lastInactivityAlertSentAt = now;
        await customer.save();
        sentCount += 1;
      } catch (customerError) {
        console.error(
          `Failed inactivity alert for customer ${customer._id}:`,
          customerError.message
        );
      }
    }

    if (sentCount > 0) {
      console.log(`Inactivity alerts sent to ${sentCount} customers`);
    }
  } catch (error) {
    console.error('Error in checkInactiveCustomersWeekly:', error);
  }
};

exports.getOrderStats = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    const match = {};

    if (startDate || endDate) {
      match.orderDate = {};
      if (startDate) match.orderDate.$gte = new Date(startDate);
      if (endDate) match.orderDate.$lte = new Date(endDate);
    }

    const stats = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          totalSupplierOrders: {
            $sum: { $cond: [{ $eq: ['$orderSource', 'مورد'] }, 1, 0] }
          },
          totalCustomerOrders: {
            $sum: { $cond: [{ $eq: ['$orderSource', 'عميل'] }, 1, 0] }
          },
          totalMergedOrders: {
            $sum: { $cond: [{ $eq: ['$orderSource', 'مدمج'] }, 1, 0] }
          },
          totalQuantity: { $sum: '$quantity' },
          totalPrice: { $sum: '$totalPrice' },
          pendingOrders: {
            $sum: { $cond: [{ $in: ['$status', ['قيد الانتظار', 'في انتظار إنشاء طلب العميل']] }, 1, 0] }
          },
          inProgressOrders: {
  $sum: {
    $cond: [
      {
        $or: [
          { $in: ['$status', ['مخصص للعميل', 'في انتظار التحميل', 'جاهز للتحميل', 'في الطريق']] },
          { $eq: ['$orderSource', 'مدمج'] }
        ]
      },
      1,
      0
    ]
  }
}
,
          completedOrders: {
            $sum: {
              $cond: [
                {
                  $and: [
                    { $eq: ['$orderSource', 'مدمج'] },
                    { $eq: ['$status', 'تم التنفيذ'] }
                  ]
                },
                1,
                0
              ]
            }
          },
          cancelledOrders: {
            $sum: { $cond: [{ $eq: ['$status', 'ملغى'] }, 1, 0] }
          }
        }
      }
    ]);

    const cityStats = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$city',
          count: { $sum: 1 },
          totalQuantity: { $sum: '$quantity' },
          totalPrice: { $sum: '$totalPrice' }
        }
      },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    const statusStats = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 }
        }
      },
      { $sort: { count: -1 } }
    ]);

    const productStats = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$productType',
          count: { $sum: 1 },
          totalQuantity: { $sum: '$quantity' }
        }
      },
      { $sort: { count: -1 } }
    ]);

    res.json({
      overall: stats[0] || {
        totalOrders: 0,
        totalSupplierOrders: 0,
        totalCustomerOrders: 0,
        totalMergedOrders: 0,
        totalQuantity: 0,
        totalPrice: 0,
        pendingOrders: 0,
        inProgressOrders: 0,
        completedOrders: 0,
        cancelledOrders: 0
      },
      byCity: cityStats,
      byStatus: statusStats,
      byProduct: productStats,
      period: {
        startDate: startDate || null,
        endDate: endDate || null
      }
    });
  } catch (error) {
    console.error('Error getting order stats:', error);
    res.status(500).json({ error: 'حدث خطأ في جلب الإحصائيات' });
  }
};


exports.advancedSearch = async (req, res) => {
  try {
    const {
      searchType,
      keyword,
      dateField,
      startDate,
      endDate,
      statuses,
      minAmount,
      maxAmount,
      cities,
      areas,
      productTypes,
      fuelTypes,
      paymentStatuses,
      sortBy = 'orderDate',
      sortOrder = 'desc',
      page = 1,
      limit = 50
    } = req.query;

    const filter = {};
    const skip = (page - 1) * limit;

    if (searchType === 'customer') filter.orderSource = 'عميل';
    if (searchType === 'supplier') filter.orderSource = 'مورد';
    if (searchType === 'mixed') filter.orderSource = 'مدمج';

    if (keyword) {
      const r = new RegExp(keyword, 'i');
      filter.$or = [
        { orderNumber: r },
        { customerName: r },
        { supplierName: r },
        { driverName: r },
        { customerCode: r },
        { supplierOrderNumber: r }
      ];
    }

    if (dateField && (startDate || endDate)) {
      filter[dateField] = {};
      if (startDate) filter[dateField].$gte = new Date(startDate);
      if (endDate) filter[dateField].$lte = new Date(endDate);
    }

    if (statuses) {
      filter.status = { $in: Array.isArray(statuses) ? statuses : [statuses] };
    }

    if (minAmount || maxAmount) {
      filter.totalPrice = {};
      if (minAmount) filter.totalPrice.$gte = Number(minAmount);
      if (maxAmount) filter.totalPrice.$lte = Number(maxAmount);
    }

    if (cities) {
      filter.city = { $in: (Array.isArray(cities) ? cities : [cities]).map(c => new RegExp(c, 'i')) };
    }

    if (areas) {
      filter.area = { $in: (Array.isArray(areas) ? areas : [areas]).map(a => new RegExp(a, 'i')) };
    }

    if (productTypes) filter.productType = { $in: [].concat(productTypes) };
    if (fuelTypes) filter.fuelType = { $in: [].concat(fuelTypes) };
    if (paymentStatuses) filter.paymentStatus = { $in: [].concat(paymentStatuses) };

    const sort = { [sortBy]: sortOrder === 'asc' ? 1 : -1 };

    const orders = await Order.find(filter)
      .populate('customer supplier driver createdBy')
      .sort(sort)
      .skip(skip)
      .limit(Number(limit));

    const total = await Order.countDocuments(filter);

    res.json({
      success: true,
      orders,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Advanced search error:', error);
    res.status(500).json({ success: false, error: 'حدث خطأ في البحث المتقدم' });
  }
};

exports.updateStatistics = async (req, res) => {
  try {
    const drivers = await Driver.find({ status: 'نشط' });

    for (const driver of drivers) {
      const stats = await Order.aggregate([
        { $match: { driver: driver._id } },
        {
          $group: {
            _id: null,
            totalOrders: { $sum: 1 },
            totalEarnings: { $sum: { $ifNull: ['$driverEarnings', 0] } },
            totalDistance: { $sum: { $ifNull: ['$distance', 0] } },
            avgRating: { $avg: { $ifNull: ['$driverRating', 0] } }
          }
        }
      ]);

      if (stats[0]) {
        Object.assign(driver, {
          totalDeliveries: stats[0].totalOrders,
          totalEarnings: stats[0].totalEarnings,
          totalDistance: stats[0].totalDistance,
          averageRating: stats[0].avgRating || 0
        });
        await driver.save();
      }
    }

    res.json({ success: true, message: 'تم تحديث الإحصائيات بنجاح' });
  } catch (error) {
    console.error('Update statistics error:', error);
    res.status(500).json({ success: false, error: 'حدث خطأ في تحديث الإحصائيات' });
  }
};





