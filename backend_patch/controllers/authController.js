const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');

const Company = require('../models/Company');
const User = require('../models/User');
const AuthLoginDevice = require('../models/AuthLoginDevice');
const NotificationService = require('../services/notificationService');
const { sendEmail } = require('../services/emailService');
const { uniqueStationIds } = require('../utils/stationAccess');
const { runWithTenant } = require('../utils/tenantContext');

const LOGIN_TYPES = new Set(['email', 'phone', 'username']);
const MAX_FAILED_ATTEMPTS = 5;
const OTP_EXPIRY_MINUTES = 10;

const generateToken = ({
  userId,
  companyId = '',
  authVersion = 0,
  deviceId = '',
  sessionNonce = '',
}) => {
  return jwt.sign(
    {
      userId,
      ...(companyId ? { companyId: String(companyId) } : {}),
      authVersion: Number(authVersion || 0),
      ...(deviceId ? { deviceId } : {}),
      ...(sessionNonce ? { sessionNonce } : {}),
    },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: '7d' }
  );
};

const generateSessionNonce = () => crypto.randomBytes(24).toString('hex');

const normalizeCompanyName = (value) => String(value || '').trim();

const slugifyCompanyName = (name) => {
  const base = String(name || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-+/g, '-');
  return base;
};

const generateUniqueCompanySlug = async (companyName) => {
  const base = slugifyCompanyName(companyName) || 'company';
  for (let counter = 0; counter <= 1000; counter += 1) {
    const slug = counter === 0 ? base : `${base}-${counter}`;
    const exists = await Company.exists({ slug });
    if (!exists) return slug;
  }

  const suffix = crypto.randomBytes(4).toString('hex');
  return `${base}-${suffix}`;
};

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();
const normalizeUsername = (value) => String(value || '').trim().toLowerCase();
const normalizePhone = (value) => String(value || '').trim().replace(/\s+/g, '');

const normalizeLoginType = (value) => {
  const normalized = String(value || '').trim().toLowerCase();
  return LOGIN_TYPES.has(normalized) ? normalized : 'phone';
};

const normalizeIdentifier = (loginType, identifier) => {
  switch (normalizeLoginType(loginType)) {
    case 'email':
      return normalizeEmail(identifier);
    case 'username':
      return normalizeUsername(identifier);
    case 'phone':
    default:
      return normalizePhone(identifier);
  }
};

const hashOtp = (otp) =>
  crypto.createHash('sha256').update(String(otp)).digest('hex');

const generateOtpCode = () =>
  String(crypto.randomInt(0, 1000000)).padStart(6, '0');

const sanitizePlatform = (value) => {
  const platform = String(value || '').trim().toLowerCase();
  return ['web', 'android', 'ios', 'desktop'].includes(platform)
    ? platform
    : 'unknown';
};

const detectPlatformFromUserAgent = (userAgent) => {
  const normalized = String(userAgent || '').toLowerCase();
  if (!normalized) return 'unknown';
  if (normalized.includes('android')) return 'android';
  if (
    normalized.includes('iphone') ||
    normalized.includes('ipad') ||
    normalized.includes('ios')
  ) {
    return 'ios';
  }
  if (
    normalized.includes('windows') ||
    normalized.includes('macintosh') ||
    normalized.includes('linux')
  ) {
    return 'desktop';
  }
  return 'web';
};

const buildDeviceContext = (req) => {
  const userAgent = String(req.headers['user-agent'] || '').trim();
  const fallbackPlatform = detectPlatformFromUserAgent(userAgent);
  const platform = sanitizePlatform(req.body?.platform || fallbackPlatform);
  const deviceName =
    String(req.body?.deviceName || '').trim() || `client-${platform}`;
  const ipAddress = String(
    req.headers['x-forwarded-for'] || req.ip || req.connection?.remoteAddress || ''
  ).trim();

  let deviceId = String(req.body?.deviceId || '').trim();
  if (!deviceId) {
    deviceId = crypto
      .createHash('sha1')
      .update([ipAddress, userAgent, deviceName, platform].join('|'))
      .digest('hex');
  }

  return {
    deviceId,
    deviceName,
    platform,
    userAgent,
    ipAddress,
  };
};

const buildUserLookupQuery = (loginType, identifier) => {
  switch (normalizeLoginType(loginType)) {
    case 'email':
      return { email: normalizeEmail(identifier) };
    case 'username':
      return { username: normalizeUsername(identifier) };
    case 'phone':
    default:
      return { phone: normalizePhone(identifier) };
  }
};

const findUserByIdentifier = (loginType, identifier) =>
  User.findOne(buildUserLookupQuery(loginType, identifier)).populate(
    'stationId',
    '_id stationName stationCode'
  ).populate('stationIds', '_id stationName stationCode')
    .populate('supplierId', '_id name company');

const serializeUser = (user) => {
  const station = user?.stationId;
  const stationId =
    station && typeof station === 'object' && station._id ? station._id : station;
  const stationIds = uniqueStationIds(
    Array.isArray(user?.stationIds)
      ? user.stationIds.map((assignedStation) =>
          assignedStation &&
          typeof assignedStation === 'object' &&
          assignedStation._id
            ? assignedStation._id
            : assignedStation
        )
      : []
  );

  return {
    id: user._id,
    name: user.name,
    username: user.username || '',
    email: user.email,
    role: user.role,
    companyId: user.companyId ? user.companyId.toString() : null,
    company: user.company,
    phone: user.phone || '',
    permissions: user.permissions || [],
    isBlocked: Boolean(user.isBlocked),
    createdAt: user.createdAt,
    stationId: stationId || null,
    stationIds,
    driverId: user?.driverId ? user.driverId.toString() : null,
    supplierId:
      user?.supplierId && typeof user.supplierId === 'object' && user.supplierId._id
        ? user.supplierId._id.toString()
        : user?.supplierId?.toString?.() || null,
    supplierName:
      user?.supplierId && typeof user.supplierId === 'object'
        ? user.supplierId.name || null
        : null,
    stationName: station?.stationName || null,
    stationCode: station?.stationCode || null,
  };
};

const serializeDeviceUser = (user) => {
  if (!user) return null;

  if (typeof user === 'object') {
    return {
      id: user._id || user.id || null,
      name: user.name || '',
      email: user.email || '',
      username: user.username || '',
      role: user.role || '',
      phone: user.phone || '',
      company: user.company || '',
    };
  }

  return {
    id: user,
    name: '',
    email: '',
    username: '',
    role: '',
    phone: '',
    company: '',
  };
};

const serializeManagedDevice = (device) => ({
  id: device._id,
  deviceId: device.deviceId,
  deviceName: device.deviceName || '',
  platform: device.platform || 'unknown',
  userAgent: device.userAgent || '',
  ipAddress: device.ipAddress || '',
  failedAttempts: Number(device.failedAttempts || 0),
  blocked: Boolean(device.blocked),
  isLoggedIn: Boolean(device.isLoggedIn),
  blockedAt: device.blockedAt || null,
  blockReason: device.blockReason || '',
  lastFailureReason: device.lastFailureReason || '',
  lastIdentifier: device.lastIdentifier || '',
  lastLoginType: device.lastLoginType || 'phone',
  lastSeenAt: device.lastSeenAt || null,
  lastLoginAt: device.lastLoginAt || null,
  lastLogoutAt: device.lastLogoutAt || null,
  lastLogoutReason: device.lastLogoutReason || '',
  currentSessionStartedAt: device.currentSessionStartedAt || null,
  currentSessionRevokedAt: device.currentSessionRevokedAt || null,
  currentSessionRevokedByName:
    device.currentSessionRevokedBy &&
    typeof device.currentSessionRevokedBy === 'object'
      ? device.currentSessionRevokedBy.name || ''
      : device.currentSessionRevokedByName || '',
  currentSessionUser:
    device.currentSessionUser && typeof device.currentSessionUser === 'object'
      ? serializeDeviceUser(device.currentSessionUser)
      : null,
  linkedUsers: Array.isArray(device.linkedUsers)
    ? device.linkedUsers
        .map((linkedUser) =>
          linkedUser && typeof linkedUser === 'object'
            ? serializeDeviceUser(linkedUser)
            : null
        )
        .filter(Boolean)
    : [],
  matchedUserId:
    device.lastMatchedUser && typeof device.lastMatchedUser === 'object'
      ? device.lastMatchedUser._id
      : device.lastMatchedUser || null,
  matchedUserName:
    device.lastMatchedUser && typeof device.lastMatchedUser === 'object'
      ? device.lastMatchedUser.name || ''
      : '',
  matchedUserEmail:
    device.lastMatchedUser && typeof device.lastMatchedUser === 'object'
      ? device.lastMatchedUser.email || ''
      : device.lastMatchedUserEmail || '',
  matchedUsername:
    device.lastMatchedUser && typeof device.lastMatchedUser === 'object'
      ? device.lastMatchedUser.username || ''
      : device.lastMatchedUsername || '',
  unblockedAt: device.unblockedAt || null,
  unblockedByName:
    device.unblockedBy && typeof device.unblockedBy === 'object'
      ? device.unblockedBy.name || ''
      : device.unblockedByName || '',
});

const serializeBlockedDevice = (device) => serializeManagedDevice(device);

const applyDeviceContext = (device, deviceContext) => {
  device.deviceName = deviceContext.deviceName;
  device.platform = deviceContext.platform;
  device.userAgent = deviceContext.userAgent;
  device.ipAddress = deviceContext.ipAddress;
  device.lastSeenAt = new Date();
};

const activateDeviceSession = async ({
  req,
  user,
  loginType,
  identifier,
}) => {
  const deviceContext = buildDeviceContext(req);
  let device = await AuthLoginDevice.findOne({ deviceId: deviceContext.deviceId });

  if (!device) {
    device = new AuthLoginDevice({ deviceId: deviceContext.deviceId });
  }

  applyDeviceContext(device, deviceContext);

  const normalizedLoginType = normalizeLoginType(loginType);
  const normalizedIdentifier = normalizeIdentifier(loginType, identifier);
  const userId = user._id.toString();

  device.failedAttempts = 0;
  device.lastFailureReason = '';
  device.lastIdentifier = normalizedIdentifier;
  device.lastLoginType = normalizedLoginType;
  device.lastMatchedUser = user._id;
  device.lastMatchedUserEmail = user.email || '';
  device.lastMatchedUsername = user.username || '';
  device.lastLoginAt = new Date();
  device.lastLogoutReason = '';
  device.blocked = false;
  device.isLoggedIn = true;
  device.currentSessionUser = user._id;
  device.currentSessionStartedAt = new Date();
  device.currentSessionRevokedAt = undefined;
  device.currentSessionRevokedBy = null;
  device.currentSessionRevokedByName = '';
  device.sessionNonce = generateSessionNonce();

  const linkedUsers = Array.isArray(device.linkedUsers) ? device.linkedUsers : [];
  const hasLinkedUser = linkedUsers.some(
    (linkedUserId) => linkedUserId && linkedUserId.toString() === userId
  );

  if (!hasLinkedUser) {
    linkedUsers.push(user._id);
  }

  device.linkedUsers = linkedUsers;
  await device.save();

  return { device, deviceContext };
};

const revokeDeviceSession = async ({
  device,
  actedBy = null,
  reason = '',
  keepBlockedState = false,
}) => {
  device.isLoggedIn = false;
  device.currentSessionUser = null;
  device.currentSessionStartedAt = undefined;
  device.currentSessionRevokedAt = new Date();
  device.currentSessionRevokedBy = actedBy?._id || null;
  device.currentSessionRevokedByName = actedBy?.name || '';
  device.lastLogoutAt = new Date();
  device.lastLogoutReason = reason;
  device.sessionNonce = generateSessionNonce();
  device.lastSeenAt = new Date();

  if (!keepBlockedState) {
    device.blocked = false;
  }

  await device.save();
  return device;
};

const buildDeviceManagementQuery = (filter = {}) =>
  AuthLoginDevice.find(filter)
    .populate('lastMatchedUser', 'name email username role phone company')
    .populate('unblockedBy', 'name')
    .populate('currentSessionUser', 'name email username role phone company')
    .populate('linkedUsers', 'name email username role phone company')
    .populate('currentSessionRevokedBy', 'name');

const buildManagedDeviceByIdQuery = (deviceId) =>
  AuthLoginDevice.findById(deviceId)
    .populate('lastMatchedUser', 'name email username role phone company')
    .populate('unblockedBy', 'name')
    .populate('currentSessionUser', 'name email username role phone company')
    .populate('linkedUsers', 'name email username role phone company')
    .populate('currentSessionRevokedBy', 'name');

const syncUserOnlineState = async (userId) => {
  if (!userId) return;

  const activeDeviceCount = await AuthLoginDevice.countDocuments({
    currentSessionUser: userId,
    isLoggedIn: true,
    blocked: { $ne: true },
  });

  await User.findByIdAndUpdate(userId, {
    $set: {
      isOnline: activeDeviceCount > 0,
      lastSeenAt: new Date(),
    },
  });
};

const maskEmail = (email) => {
  const normalized = normalizeEmail(email);
  const [localPart, domain] = normalized.split('@');
  if (!localPart || !domain) return normalized;

  if (localPart.length <= 2) {
    return `${localPart[0] || '*'}***@${domain}`;
  }

  return `${localPart.slice(0, 2)}***@${domain}`;
};

const createOtpEmailHtml = ({ name, otp }) => `
  <div dir="rtl" style="font-family:Arial,sans-serif;background:#f5f7fb;padding:24px">
    <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e5e7eb">
      <div style="background:linear-gradient(135deg,#0f1a5c,#1a2980);padding:28px 24px;color:#fff">
        <h2 style="margin:0 0 8px;font-weight:700">رمز التحقق لتسجيل الدخول</h2>
        <p style="margin:0;opacity:.9">نظام نبراس</p>
      </div>
      <div style="padding:28px 24px;color:#1f2937">
        <p style="margin-top:0">مرحباً ${name || 'مستخدمنا'}،</p>
        <p>استخدم رمز التحقق التالي لإكمال تسجيل الدخول:</p>
        <div style="margin:24px 0;padding:18px;border-radius:14px;background:#eff6ff;border:1px dashed #2563eb;text-align:center">
          <span style="font-size:32px;letter-spacing:8px;font-weight:700;color:#1d4ed8">${otp}</span>
        </div>
        <p>هذا الرمز صالح لمدة ${OTP_EXPIRY_MINUTES} دقائق فقط.</p>
        <p style="margin-bottom:0;color:#6b7280;font-size:13px">إذا لم تطلب تسجيل الدخول، يمكنك تجاهل هذه الرسالة.</p>
      </div>
    </div>
  </div>
`;

const createWelcomeEmailHtml = ({ name }) => `
  <div dir="rtl" style="font-family:Arial,sans-serif;padding:20px">
    <h2>مرحباً ${name || ''}</h2>
    <p>تم إنشاء حسابك بنجاح في نظام نبراس.</p>
  </div>
`;

const createLegacyLoginEmailHtml = ({ name }) => `
  <div dir="rtl" style="font-family:Arial,sans-serif;padding:20px">
    <h2>تم تسجيل الدخول إلى حسابك</h2>
    <p>مرحباً ${name || ''}، تم تسجيل الدخول إلى الحساب بنجاح.</p>
  </div>
`;

const notifyOwnersAboutBlockedDevice = async (device) => {
  const owners = await User.find({ role: 'owner', isBlocked: { $ne: true } })
    .select('_id')
    .lean();

  if (!owners.length) {
    return;
  }

  const recipients = owners
    .map((owner) => owner?._id)
    .filter(Boolean);

  if (!recipients.length) {
    return;
  }

  const reasonLabel =
    device.blockReason || 'تجاوز عدد محاولات الدخول المسموح به';

  await NotificationService.send({
    type: 'system_alert',
    title: 'تم حظر جهاز من تسجيل الدخول',
    message: `${device.deviceName || device.deviceId} - ${reasonLabel}`,
    data: {
      reportType: 'blocked_login_device',
      deviceRecordId: String(device._id),
      deviceId: device.deviceId,
      deviceName: device.deviceName || '',
      platform: device.platform || 'unknown',
      failedAttempts: device.failedAttempts || 0,
      identifier: device.lastIdentifier || '',
      reason: reasonLabel,
    },
    recipients,
    priority: 'high',
    channels: ['in_app', 'push'],
  });
};

const recordFailedDeviceAttempt = async ({
  req,
  loginType,
  identifier,
  matchedUser = null,
  reason,
}) => {
  const deviceContext = buildDeviceContext(req);
  const normalizedIdentifier = normalizeIdentifier(loginType, identifier);

  let device = await AuthLoginDevice.findOne({ deviceId: deviceContext.deviceId });

  if (!device) {
    device = new AuthLoginDevice({ deviceId: deviceContext.deviceId });
  }

  applyDeviceContext(device, deviceContext);
  device.lastIdentifier = normalizedIdentifier;
  device.lastLoginType = normalizeLoginType(loginType);
  device.lastFailureReason = reason;
  device.lastMatchedUser = matchedUser?._id || null;
  device.lastMatchedUserEmail = matchedUser?.email || '';
  device.lastMatchedUsername = matchedUser?.username || '';

  if (matchedUser?._id) {
    const matchedUserId = matchedUser._id.toString();
    const linkedUsers = Array.isArray(device.linkedUsers) ? device.linkedUsers : [];

    if (
      !linkedUsers.some(
        (linkedUserId) => linkedUserId && linkedUserId.toString() === matchedUserId
      )
    ) {
      linkedUsers.push(matchedUser._id);
      device.linkedUsers = linkedUsers;
    }
  }

  if (device.blocked) {
    await device.save();
    return { blockedNow: false };
  }

  device.failedAttempts = Number(device.failedAttempts || 0) + 1;

  let blockedNow = false;
  if (device.failedAttempts > MAX_FAILED_ATTEMPTS) {
    device.blocked = true;
    device.blockedAt = new Date();
    device.blockReason =
      reason || `تجاوز الحد المسموح من محاولات الدخول (${MAX_FAILED_ATTEMPTS})`;
    device.isLoggedIn = false;
    device.currentSessionUser = null;
    device.currentSessionStartedAt = undefined;
    device.currentSessionRevokedAt = new Date();
    device.currentSessionRevokedBy = null;
    device.currentSessionRevokedByName = 'system';
    device.lastLogoutAt = new Date();
    device.lastLogoutReason = device.blockReason;
    device.sessionNonce = generateSessionNonce();
    blockedNow = true;
  }

  await device.save();

  if (blockedNow) {
    await notifyOwnersAboutBlockedDevice(device);
  }

  return { blockedNow };
};

const resetDeviceAttempts = async (deviceId) => {
  if (!deviceId) return;

  await AuthLoginDevice.findOneAndUpdate(
    { deviceId, blocked: false },
    {
      $set: {
        failedAttempts: 0,
        lastFailureReason: '',
        lastSeenAt: new Date(),
      },
    }
  );
};

const ensureUniqueIdentityFields = async ({
  email,
  phone,
  username,
  excludeUserId,
}) => {
  if (email) {
    const existingEmailUser = await User.findOne({
      email,
      ...(excludeUserId ? { _id: { $ne: excludeUserId } } : {}),
    }).lean();

    if (existingEmailUser) {
      return 'البريد الإلكتروني مستخدم بالفعل';
    }
  }

  if (phone) {
    const existingPhoneUser = await User.findOne({
      phone,
      ...(excludeUserId ? { _id: { $ne: excludeUserId } } : {}),
    }).lean();

    if (existingPhoneUser) {
      return 'رقم الجوال مستخدم بالفعل';
    }
  }

  if (username) {
    const existingUsernameUser = await User.findOne({
      username,
      ...(excludeUserId ? { _id: { $ne: excludeUserId } } : {}),
    }).lean();

    if (existingUsernameUser) {
      return 'اسم المستخدم مستخدم بالفعل';
    }
  }

  return null;
};

exports.register = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const email = normalizeEmail(req.body.email);
    const username = normalizeUsername(req.body.username);
    const phone = normalizePhone(req.body.phone);
    const companyName = normalizeCompanyName(req.body.company);

    const conflictMessage = await ensureUniqueIdentityFields({
      email,
      phone: phone || null,
      username: username || null,
    });

    if (conflictMessage) {
      return res.status(400).json({ error: conflictMessage });
    }

    const existingCompany = await Company.findOne({ name: companyName }).lean();
    if (existingCompany) {
      return res.status(409).json({ error: 'اسم الشركة مستخدم بالفعل' });
    }

    const companySlug = await generateUniqueCompanySlug(companyName);
    const company = await Company.create({
      name: companyName,
      slug: companySlug,
    });

    const user = new User({
      name: String(req.body.name || '').trim(),
      username: username || undefined,
      email,
      password: req.body.password,
      company: company.name,
      companyId: company._id,
      phone: phone || null,
      role: 'admin',
    });

    await user.save();

    try {
      await sendEmail({
        to: user.email,
        subject: 'مرحباً بك في نظام نبراس',
        html: createWelcomeEmailHtml({ name: user.name }),
      });
    } catch (emailError) {
      console.error('Failed to send register email:', emailError.message);
    }

    return res.status(201).json({
      message: 'تم إنشاء حساب الشركة بنجاح',
      token: generateToken({
        userId: user._id,
        companyId: company._id,
        authVersion: user.authVersion,
      }),
      user: serializeUser(user),
      company: {
        id: company._id,
        name: company.name,
        slug: company.slug,
      },
    });
  } catch (error) {
    console.error('Register error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.login = async (req, res) => {
  try {
    const user = await User.findOne({
      email: normalizeEmail(req.body.email),
    })
      .populate('stationId', '_id stationName stationCode')
      .populate('stationIds', '_id stationName stationCode')
      .populate('supplierId', '_id name company');

    if (!user) {
      return res.status(401).json({ error: 'بيانات الدخول غير صحيحة' });
    }

    if (user.isBlocked) {
      return res.status(403).json({ error: 'حساب المستخدم موقوف' });
    }

    const isMatch = await user.comparePassword(req.body.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'بيانات الدخول غير صحيحة' });
    }

    const companyId = user.companyId ? user.companyId.toString() : '';
    if (!companyId) {
      return res.status(403).json({
        error:
          'الحساب غير مرتبط بشركة. برجاء تشغيل ترحيل البيانات (tenancy migration) ثم إعادة المحاولة.',
      });
    }

    return runWithTenant(companyId, async () => {
      user.lastLoginAt = new Date();
      user.isOnline = true;
      user.lastSeenAt = new Date();
      await user.save();

      const { device } = await activateDeviceSession({
        req,
        user,
        loginType: 'email',
        identifier: user.email,
      });

      try {
        await sendEmail({
          to: user.email,
          subject: 'تم تسجيل الدخول إلى حسابك',
          html: createLegacyLoginEmailHtml({ name: user.name }),
        });
      } catch (emailError) {
        console.error('Failed to send legacy login email:', emailError.message);
      }

      return res.json({
        message: 'تم تسجيل الدخول بنجاح',
        token: generateToken({
          userId: user._id,
          companyId,
          authVersion: user.authVersion,
          deviceId: device.deviceId,
          sessionNonce: device.sessionNonce,
        }),
        user: serializeUser(user),
      });
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.requestLoginOtp = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const loginType = normalizeLoginType(req.body.loginType);
    const identifier = normalizeIdentifier(loginType, req.body.identifier);
    const deviceContext = buildDeviceContext(req);

    const blockedDevice = await AuthLoginDevice.findOne({
      deviceId: deviceContext.deviceId,
      blocked: true,
    }).lean();

    if (blockedDevice) {
      return res.status(403).json({
        error:
          'تم حظر هذا الجهاز بسبب تجاوز عدد محاولات الدخول المسموح به. تم إشعار المالك للمراجعة.',
      });
    }

    const user = await findUserByIdentifier(loginType, identifier);

    if (!user) {
      const { blockedNow } = await recordFailedDeviceAttempt({
        req,
        loginType,
        identifier,
        reason: 'لا يوجد مستخدم مطابق للبيانات المدخلة',
      });

      return res.status(blockedNow ? 403 : 404).json({
        error: blockedNow
          ? 'تم حظر هذا الجهاز بسبب تجاوز عدد محاولات الدخول المسموح به. تم إشعار المالك للمراجعة.'
          : 'لا يوجد مستخدم بهذا العنوان، الرجاء التأكد من البيانات وإعادة الدخول في وقت لاحق.',
      });
    }

    if (user.isBlocked) {
      return res.status(403).json({ error: 'حساب المستخدم موقوف' });
    }

    if (!user.email) {
      return res.status(400).json({
        error: 'لا يمكن إرسال رمز التحقق لهذا المستخدم لعدم وجود بريد إلكتروني مسجل',
      });
    }

    const otp = generateOtpCode();
    user.loginOtpCodeHash = hashOtp(otp);
    user.loginOtpExpiresAt = new Date(
      Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000
    );
    user.loginOtpRequestedAt = new Date();
    user.loginOtpDeviceId = deviceContext.deviceId;
    await user.save();

    await sendEmail({
      to: user.email,
      subject: 'رمز التحقق لتسجيل الدخول',
      html: createOtpEmailHtml({ name: user.name, otp }),
      includeSystemAudit: false,
    });

    await resetDeviceAttempts(deviceContext.deviceId);

    return res.json({
      success: true,
      message: `تم إرسال رمز التحقق إلى ${maskEmail(user.email)}`,
      maskedEmail: maskEmail(user.email),
      expiresInMinutes: OTP_EXPIRY_MINUTES,
    });
  } catch (error) {
    console.error('Request login OTP error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.verifyLoginOtp = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const loginType = normalizeLoginType(req.body.loginType);
    const identifier = normalizeIdentifier(loginType, req.body.identifier);
    const otp = String(req.body.otp || '').trim();
    const deviceContext = buildDeviceContext(req);

    const blockedDevice = await AuthLoginDevice.findOne({
      deviceId: deviceContext.deviceId,
      blocked: true,
    }).lean();

    if (blockedDevice) {
      return res.status(403).json({
        error:
          'تم حظر هذا الجهاز بسبب تجاوز عدد محاولات الدخول المسموح به. تم إشعار المالك للمراجعة.',
      });
    }

    const user = await findUserByIdentifier(loginType, identifier);

    if (!user) {
      const { blockedNow } = await recordFailedDeviceAttempt({
        req,
        loginType,
        identifier,
        reason: 'محاولة تحقق لبيانات مستخدم غير موجودة',
      });

      return res.status(blockedNow ? 403 : 404).json({
        error: blockedNow
          ? 'تم حظر هذا الجهاز بسبب تجاوز عدد محاولات الدخول المسموح به. تم إشعار المالك للمراجعة.'
          : 'لا يوجد مستخدم بهذا العنوان، الرجاء التأكد من البيانات وإعادة الدخول في وقت لاحق.',
      });
    }

    if (user.isBlocked) {
      return res.status(403).json({ error: 'حساب المستخدم موقوف' });
    }

    const isOtpExpired =
      !user.loginOtpExpiresAt || user.loginOtpExpiresAt.getTime() < Date.now();
    const isOtpMismatch =
      !user.loginOtpCodeHash || user.loginOtpCodeHash !== hashOtp(otp);
    const isWrongDevice =
      !user.loginOtpDeviceId || user.loginOtpDeviceId !== deviceContext.deviceId;

    if (isOtpExpired || isOtpMismatch || isWrongDevice) {
      const reason = isWrongDevice
        ? 'محاولة إدخال رمز من جهاز مختلف عن الجهاز الذي طلب الرمز'
        : isOtpExpired
        ? 'انتهت صلاحية رمز التحقق'
        : 'تم إدخال رمز تحقق غير صحيح';

      const { blockedNow } = await recordFailedDeviceAttempt({
        req,
        loginType,
        identifier,
        matchedUser: user,
        reason,
      });

      return res.status(blockedNow ? 403 : 401).json({
        error: blockedNow
          ? 'تم حظر هذا الجهاز بسبب تجاوز عدد محاولات الدخول المسموح به. تم إشعار المالك للمراجعة.'
          : reason,
      });
    }

    const companyId = user.companyId ? user.companyId.toString() : '';
    if (!companyId) {
      return res.status(403).json({
        error:
          'الحساب غير مرتبط بشركة. برجاء تشغيل ترحيل البيانات (tenancy migration) ثم إعادة المحاولة.',
      });
    }

    return runWithTenant(companyId, async () => {
      user.loginOtpCodeHash = undefined;
      user.loginOtpExpiresAt = undefined;
      user.loginOtpRequestedAt = undefined;
      user.loginOtpDeviceId = undefined;
      user.lastLoginAt = new Date();
      user.isOnline = true;
      user.lastSeenAt = new Date();
      await user.save();

      const { device } = await activateDeviceSession({
        req,
        user,
        loginType,
        identifier,
      });

      return res.json({
        success: true,
        message: 'تم تسجيل الدخول بنجاح',
        token: generateToken({
          userId: user._id,
          companyId,
          authVersion: user.authVersion,
          deviceId: device.deviceId,
          sessionNonce: device.sessionNonce,
        }),
        user: serializeUser(user),
      });
    });
  } catch (error) {
    console.error('Verify login OTP error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.logoutCurrentSession = async (req, res) => {
  try {
    const currentSessionUserId = req.authDevice?.currentSessionUser
      ? req.authDevice.currentSessionUser.toString()
      : req.user?._id?.toString();

    if (req.authDevice) {
      await revokeDeviceSession({
        device: req.authDevice,
        actedBy: req.user,
        reason: 'تم تسجيل الخروج من التطبيق',
      });
    }

    if (req.user) {
      req.user.isOnline = false;
      req.user.lastSeenAt = new Date();
      await req.user.save();
    }

    if (currentSessionUserId) {
      await syncUserOnlineState(currentSessionUserId);
    }

    return res.json({
      success: true,
      message: 'تم تسجيل الخروج بنجاح',
    });
  } catch (error) {
    console.error('Logout current session error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.listManagedDevices = async (req, res) => {
  try {
    const devices = await buildDeviceManagementQuery({})
      .sort({ blocked: -1, isLoggedIn: -1, lastSeenAt: -1, updatedAt: -1 });

    return res.json({
      success: true,
      summary: {
        totalDevices: devices.length,
        activeSessions: devices.filter((device) => device.isLoggedIn).length,
        blockedDevices: devices.filter((device) => device.blocked).length,
      },
      devices: devices.map(serializeManagedDevice),
    });
  } catch (error) {
    console.error('List managed devices error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.blockManagedDevice = async (req, res) => {
  try {
    const device = await buildManagedDeviceByIdQuery(req.params.id);

    if (!device) {
      return res.status(404).json({ error: 'الجهاز غير موجود' });
    }

    const blockReason =
      String(req.body?.reason || '').trim() || 'تم حظر هذا الجهاز من قبل المالك';
    const currentSessionUserId = device.currentSessionUser
      ? device.currentSessionUser._id?.toString?.() ||
        device.currentSessionUser.toString()
      : null;

    device.blocked = true;
    device.blockedAt = new Date();
    device.blockReason = blockReason;
    device.failedAttempts = Math.max(
      Number(device.failedAttempts || 0),
      MAX_FAILED_ATTEMPTS + 1
    );

    await revokeDeviceSession({
      device,
      actedBy: req.user,
      reason: blockReason,
      keepBlockedState: true,
    });

    if (currentSessionUserId) {
      await syncUserOnlineState(currentSessionUserId);
    }

    return res.json({
      success: true,
      message: 'تم حظر الجهاز وتسجيل خروجه بنجاح',
      device: serializeManagedDevice(device),
    });
  } catch (error) {
    console.error('Block managed device error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.logoutManagedDevice = async (req, res) => {
  try {
    const device = await buildManagedDeviceByIdQuery(req.params.id);

    if (!device) {
      return res.status(404).json({ error: 'الجهاز غير موجود' });
    }

    const currentSessionUserId = device.currentSessionUser
      ? device.currentSessionUser._id?.toString?.() ||
        device.currentSessionUser.toString()
      : null;

    if (device.isLoggedIn) {
      await revokeDeviceSession({
        device,
        actedBy: req.user,
        reason: 'تم تسجيل خروج هذا الجهاز من لوحة التحكم',
        keepBlockedState: device.blocked,
      });
    }

    if (currentSessionUserId) {
      await syncUserOnlineState(currentSessionUserId);
    }

    return res.json({
      success: true,
      message: 'تم تسجيل خروج الجهاز بنجاح',
      device: serializeManagedDevice(device),
    });
  } catch (error) {
    console.error('Logout managed device error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.logoutAllManagedDevices = async (req, res) => {
  try {
    const activeDevices = await AuthLoginDevice.find({
      isLoggedIn: true,
    }).select('_id currentSessionUser blocked');

    const affectedUserIds = [
      ...new Set(
        activeDevices
          .map((device) =>
            device.currentSessionUser ? device.currentSessionUser.toString() : ''
          )
          .filter(Boolean)
      ),
    ];

    await AuthLoginDevice.updateMany(
      { isLoggedIn: true },
      {
        $set: {
          isLoggedIn: false,
          currentSessionUser: null,
          currentSessionRevokedAt: new Date(),
          currentSessionRevokedBy: req.user?._id || null,
          currentSessionRevokedByName: req.user?.name || '',
          lastLogoutAt: new Date(),
          lastLogoutReason: 'تم تسجيل خروج جميع الأجهزة من لوحة المالك',
          lastSeenAt: new Date(),
        },
        $unset: {
          currentSessionStartedAt: '',
          sessionNonce: '',
        },
      }
    );

    if (affectedUserIds.length) {
      await User.updateMany(
        { _id: { $in: affectedUserIds } },
        {
          $set: {
            isOnline: false,
            lastSeenAt: new Date(),
          },
        }
      );
    }

    const devices = await buildDeviceManagementQuery({})
      .sort({ blocked: -1, isLoggedIn: -1, lastSeenAt: -1, updatedAt: -1 });

    return res.json({
      success: true,
      message: 'تم تسجيل خروج جميع الأجهزة بنجاح',
      affectedDevices: activeDevices.length,
      summary: {
        totalDevices: devices.length,
        activeSessions: devices.filter((device) => device.isLoggedIn).length,
        blockedDevices: devices.filter((device) => device.blocked).length,
      },
      devices: devices.map(serializeManagedDevice),
    });
  } catch (error) {
    console.error('Logout all managed devices error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.listBlockedDevices = async (req, res) => {
  try {
    const devices = await buildDeviceManagementQuery({ blocked: true })
      .sort({ blockedAt: -1, updatedAt: -1 })
      .populate('lastMatchedUser', 'name email username');

    return res.json({
      success: true,
      devices: devices.map(serializeBlockedDevice),
    });
  } catch (error) {
    console.error('List blocked devices error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.unblockBlockedDevice = async (req, res) => {
  try {
    const device = await buildManagedDeviceByIdQuery(req.params.id);

    if (!device) {
      return res.status(404).json({ error: 'الجهاز غير موجود' });
    }

    device.blocked = false;
    device.failedAttempts = 0;
    device.blockReason = '';
    device.lastFailureReason = '';
    device.unblockedAt = new Date();
    device.unblockedBy = req.user?._id || null;
    device.unblockedByName = req.user?.name || '';
    await device.save();

    return res.json({
      success: true,
      message: 'تم فك حظر الجهاز بنجاح',
      device: serializeBlockedDevice(device),
    });
  } catch (error) {
    console.error('Unblock device error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};

exports.getProfile = async (req, res) => {
  try {
    return res.json({
      user: serializeUser(req.user),
    });
  } catch (error) {
    console.error('Profile error:', error);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
};
