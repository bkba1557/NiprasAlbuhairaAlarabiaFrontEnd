const fs = require('fs');
const path = require('path');

const backendRoot = path.resolve(
  process.argv[2] || path.join(__dirname, '..', '..', '..', 'backend')
);
const payloadRoot = path.join(__dirname, 'payload');

if (!fs.existsSync(backendRoot)) {
  throw new Error(`Backend path not found: ${backendRoot}`);
}

function readFile(relativePath) {
  return fs.readFileSync(path.join(backendRoot, relativePath), 'utf8');
}

function writeFile(relativePath, content) {
  const targetPath = path.join(backendRoot, relativePath);
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, 'utf8');
  console.log(`Updated ${relativePath}`);
}

function copyPayload(relativePath) {
  const fromPath = path.join(payloadRoot, relativePath);
  const toPath = path.join(backendRoot, relativePath);
  if (!fs.existsSync(fromPath)) {
    throw new Error(`Payload not found: ${relativePath}`);
  }
  fs.mkdirSync(path.dirname(toPath), { recursive: true });
  fs.copyFileSync(fromPath, toPath);
  console.log(`Copied ${relativePath}`);
}

function replaceOnce(content, search, replacement, label) {
  if (content.includes(replacement)) return content;
  const index = content.indexOf(search);
  if (index === -1) {
    throw new Error(`Pattern not found for ${label}`);
  }
  return content.replace(search, replacement);
}

function appendCustomerPopulateFields(content) {
  return content.replace(
    /\.populate\('customer', '([^']*)'\)/g,
    (fullMatch, fields) => {
      const tokens = new Set(fields.split(/\s+/).filter(Boolean));
      tokens.add('fuelPricePerLiter');
      tokens.add('fuelPricing');
      return `.populate('customer', '${Array.from(tokens).join(' ')}')`;
    }
  );
}

function patchCustomerModel() {
  let content = readFile('models/Customer.js');

  content = replaceOnce(
    content,
    'const customerSchema = new mongoose.Schema({',
    `const customerFuelPricingSchema = new mongoose.Schema(
  {
    fuelType: {
      type: String,
      enum: ['بنزين 91', 'بنزين 95', 'ديزل', 'كيروسين'],
      required: true,
      trim: true,
    },
    pricePerLiter: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
  },
  { _id: false }
);

const customerSchema = new mongoose.Schema({`,
    'customer fuel pricing schema'
  );

  content = replaceOnce(
    content,
    '  documents: [customerDocumentSchema]\n});',
    `  fuelPricePerLiter: {\n    type: Number,\n    min: 0\n  },\n  fuelPricing: {\n    type: [customerFuelPricingSchema],\n    default: []\n  },\n  documents: [customerDocumentSchema]\n});`,
    'customer pricing fields'
  );

  writeFile('models/Customer.js', content);
}

function patchCustomerController() {
  let content = readFile('controllers/customerController.js');

  content = replaceOnce(
    content,
    'const appendProvidedDocuments = ({ customer, documents, user }) => {',
    `const parseCustomerPricingValue = (value) => {
  if (typeof value === 'string') {
    const text = value.trim();
    if (!text) return null;
    try {
      return JSON.parse(text);
    } catch (_) {
      return null;
    }
  }
  return value && typeof value === 'object' ? value : null;
};

const buildCustomerPricingFields = (payload = {}) => {
  const fields = {};

  if (Object.prototype.hasOwnProperty.call(payload, 'fuelPricePerLiter')) {
    const legacyFuelPrice = Number(payload.fuelPricePerLiter);
    fields.fuelPricePerLiter = Number.isFinite(legacyFuelPrice)
      ? legacyFuelPrice
      : undefined;
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'fuelPricing')) {
    const parsedValue = parseCustomerPricingValue(payload.fuelPricing);
    const rawEntries = Array.isArray(parsedValue)
      ? parsedValue
      : parsedValue && typeof parsedValue === 'object'
        ? Object.entries(parsedValue).map(([fuelType, pricePerLiter]) => ({
            fuelType,
            pricePerLiter,
          }))
        : [];

    fields.fuelPricing = rawEntries
      .map((entry) => ({
        fuelType: String(entry && entry.fuelType ? entry.fuelType : '').trim(),
        pricePerLiter: Number(entry && entry.pricePerLiter),
      }))
      .filter(
        (entry) =>
          entry.fuelType &&
          Number.isFinite(entry.pricePerLiter) &&
          entry.pricePerLiter >= 0
      );
  }

  return fields;
};

const appendProvidedDocuments = ({ customer, documents, user }) => {`,
    'customer controller pricing helpers'
  );

  content = replaceOnce(
    content,
    '      notes,\n      createdBy: req.user._id,\n    });',
    '      notes,\n      ...buildCustomerPricingFields(req.body),\n      createdBy: req.user._id,\n    });',
    'create customer pricing fields'
  );

  content = replaceOnce(
    content,
    '    const updates = { ...req.body };',
    '    const updates = { ...req.body };\n\n    const pricingFields = buildCustomerPricingFields(updates);\n    delete updates.fuelPricing;\n    delete updates.fuelPricePerLiter;',
    'update customer pricing extraction'
  );

  content = replaceOnce(
    content,
    '    Object.assign(customer, updates);\n    await customer.save();',
    '    Object.assign(customer, updates);\n    Object.assign(customer, pricingFields);\n    await customer.save();',
    'update customer pricing assignment'
  );

  writeFile('controllers/customerController.js', content);
}

function patchOrderModel() {
  let content = readFile('models/Order.js');

  content = replaceOnce(
    content,
    "  totalPrice: {\n    type: Number,\n    min: 0\n  },\n  paymentMethod: {",
    `  totalPrice: {\n    type: Number,\n    min: 0\n  },\n  vatRate: {\n    type: Number,\n    min: 0,\n    default: 0.15\n  },\n  vatAmount: {\n    type: Number,\n    min: 0,\n    default: 0\n  },\n  totalPriceWithVat: {\n    type: Number,\n    min: 0,\n    default: 0\n  },\n  transportSourceCity: {\n    type: String,\n    trim: true\n  },\n  transportCapacityLiters: {\n    type: Number,\n    min: 0\n  },\n  pricingSnapshot: {\n    type: mongoose.Schema.Types.Mixed\n  },\n  transportPricingOverride: {\n    type: mongoose.Schema.Types.Mixed\n  },\n  paymentMethod: {`,
    'order pricing schema fields'
  );

  content = replaceOnce(
    content,
    '    if (this.quantity && this.unitPrice) {\n      this.totalPrice = this.quantity * this.unitPrice;\n    }',
    `    if (\n      (this.totalPrice === undefined || this.totalPrice === null) &&\n      this.quantity !== undefined &&\n      this.unitPrice !== undefined &&\n      this.unitPrice !== null\n    ) {\n      this.totalPrice = this.quantity * this.unitPrice;\n    }\n\n    if (\n      (this.totalPriceWithVat === undefined || this.totalPriceWithVat === null) &&\n      this.totalPrice !== undefined &&\n      this.totalPrice !== null\n    ) {\n      const effectiveVatRate =\n        this.vatRate !== undefined && this.vatRate !== null ? this.vatRate : 0.15;\n      if (this.vatAmount === undefined || this.vatAmount === null) {\n        this.vatAmount = this.totalPrice * effectiveVatRate;\n      }\n      this.totalPriceWithVat = this.totalPrice + (this.vatAmount || 0);\n    }`,
    'order price calculation middleware'
  );

  writeFile('models/Order.js', content);
}

function patchOrderController() {
  let content = readFile('controllers/orderController.js');
  content = appendCustomerPopulateFields(content);

  content = replaceOnce(
    content,
    "const NotificationService = require('../services/notificationService');",
    "const NotificationService = require('../services/notificationService');\nconst { buildCustomerOrderPricing } = require('../services/orderPricingService');",
    'order pricing service import'
  );

  content = replaceOnce(
    content,
    '        orderData.address = orderData.address ?? null;\n      }\n\n      if (orderData.orderSource === \'مورد\') {',
    `        orderData.address = orderData.address ?? null;\n\n        try {\n          Object.assign(\n            orderData,\n            await buildCustomerOrderPricing({\n              customer: customerDoc,\n              payload: orderData,\n            })\n          );\n        } catch (pricingError) {\n          return res.status(400).json({ error: pricingError.message });\n        }\n      }\n\n      if (orderData.orderSource === 'مورد') {`,
    'create order pricing calculation'
  );

  content = replaceOnce(
    content,
    '    if (req.query.productType) {\n      filter.productType = req.query.productType;\n    }\n    \n    if (req.query.fuelType) {',
    `    if (req.query.productType) {\n      filter.productType = req.query.productType;\n    }\n\n    if (req.query.requestType) {\n      filter.requestType = req.query.requestType;\n    }\n    \n    if (req.query.fuelType) {`,
    'get orders request type filter'
  );

  content = replaceOnce(
    content,
    "'unitPrice', 'totalPrice', 'paymentMethod', 'paymentStatus',",
    "'unitPrice', 'totalPrice', 'vatRate', 'vatAmount', 'totalPriceWithVat', 'transportSourceCity', 'transportCapacityLiters', 'pricingSnapshot', 'transportPricingOverride', 'paymentMethod', 'paymentStatus',",
    'update order allowed pricing fields'
  );

  content = replaceOnce(
    content,
    "      // ============================================\n      // 📍 تحديث موقع العميل\n      // ============================================\n      if (",
    `      const pricingFields = [\n        'customer',\n        'requestType',\n        'quantity',\n        'fuelType',\n        'vatRate',\n        'transportSourceCity',\n        'transportCapacityLiters',\n        'transportPricingOverride',\n        'pricingSnapshot',\n      ];\n\n      const shouldRecalculateCustomerPricing =\n        isCustomerOrder &&\n        pricingFields.some((field) =>\n          Object.prototype.hasOwnProperty.call(updates, field)\n        );\n\n      if (shouldRecalculateCustomerPricing) {\n        const pricingCustomerId =\n          updates.customer || (order.customer && (order.customer._id || order.customer));\n        const pricingCustomer = pricingCustomerId\n          ? await Customer.findById(pricingCustomerId)\n          : null;\n\n        if (!pricingCustomer) {\n          return res.status(400).json({ error: 'العميل غير موجود' });\n        }\n\n        try {\n          Object.assign(\n            updates,\n            await buildCustomerOrderPricing({\n              customer: pricingCustomer,\n              payload: {\n                ...order.toObject(),\n                ...updates,\n                customer: pricingCustomer._id.toString(),\n                requestType: updates.requestType || order.requestType || 'شراء',\n              },\n            })\n          );\n        } catch (pricingError) {\n          return res.status(400).json({ error: pricingError.message });\n        }\n      }\n\n      // ============================================\n      // 📍 تحديث موقع العميل\n      // ============================================\n      if (`,
    'update order pricing calculation'
  );

  content = replaceOnce(
    content,
    '      // معلومات السعر\n      unitPrice: supplierOrder.unitPrice,\n      totalPrice: supplierOrder.unitPrice ? supplierOrder.unitPrice * customerQty : 0,\n      paymentMethod: supplierOrder.paymentMethod,\n      paymentStatus: supplierOrder.paymentStatus,\n      driverEarnings: supplierOrder.driverEarnings || 0,',
    `      // معلومات السعر\n      unitPrice: customerOrder.unitPrice,\n      totalPrice: customerOrder.totalPrice,\n      vatRate: customerOrder.vatRate,\n      vatAmount: customerOrder.vatAmount,\n      totalPriceWithVat: customerOrder.totalPriceWithVat,\n      transportSourceCity: customerOrder.transportSourceCity,\n      transportCapacityLiters: customerOrder.transportCapacityLiters,\n      pricingSnapshot: customerOrder.pricingSnapshot,\n      transportPricingOverride: customerOrder.transportPricingOverride,\n      paymentMethod: customerOrder.paymentMethod || supplierOrder.paymentMethod,\n      paymentStatus: customerOrder.paymentStatus || supplierOrder.paymentStatus,\n      driverEarnings: supplierOrder.driverEarnings || 0,`,
    'merge order pricing copy'
  );

  writeFile('controllers/orderController.js', content);
}

function patchReportController() {
  let content = readFile('controllers/reportController.js');

  content = replaceOnce(
    content,
    '    const match = {};\n    const skip = (page - 1) * limit;',
    "    const match = {\n      orderSource: 'عميل',\n      customer: { $ne: null },\n    };\n    const skip = (page - 1) * limit;",
    'customer report base match'
  );

  content = replaceOnce(
    content,
    '    const aggregation = [\n      { $match: match },\n      {\n        $lookup: {',
    `    const aggregation = [\n      { $match: match },\n      {\n        $addFields: {\n          _billingAmount: {\n            $ifNull: [\n              '$totalPriceWithVat',\n              {\n                $ifNull: ['$pricingSnapshot.totalWithVat', '$totalPrice'],\n              },\n            ],\n          },\n        },\n      },\n      {\n        $lookup: {`,
    'customer report billing amount stage'
  );

  content = replaceOnce(
    content,
    "          totalAmount: { $sum: '$totalPrice' },",
    "          totalAmount: { $sum: '$_billingAmount' },",
    'customer report total amount'
  );

  content = replaceOnce(
    content,
    "          avgOrderValue: { $avg: '$totalPrice' },",
    "          avgOrderValue: { $avg: '$_billingAmount' },",
    'customer report average amount'
  );

  writeFile('controllers/reportController.js', content);
}

function patchServer() {
  let content = readFile('server.js');

  content = replaceOnce(
    content,
    "const systemPauseRoutes = require('./routes/systemPauseRoutes');",
    "const systemPauseRoutes = require('./routes/systemPauseRoutes');\nconst transportPricingRoutes = require('./routes/transportPricingRoutes');\nconst customerTreasuryRoutes = require('./routes/customerTreasuryRoutes');",
    'server route imports'
  );

  content = replaceOnce(
    content,
    "app.use('/api/system-pause', systemPauseRoutes);",
    "app.use('/api/system-pause', systemPauseRoutes);\napp.use('/api/transport-pricing', transportPricingRoutes);\napp.use('/api/customer-treasury', customerTreasuryRoutes);",
    'server route mounts'
  );

  writeFile('server.js', content);
}

function run() {
  patchCustomerModel();
  patchCustomerController();
  patchOrderModel();
  patchOrderController();
  patchReportController();
  patchServer();

  copyPayload('models/TransportPricingRule.js');
  copyPayload('models/CustomerTreasuryBranch.js');
  copyPayload('models/CustomerTreasuryReceipt.js');
  copyPayload('services/orderPricingService.js');
  copyPayload('controllers/transportPricingController.js');
  copyPayload('controllers/customerTreasuryController.js');
  copyPayload('routes/transportPricingRoutes.js');
  copyPayload('routes/customerTreasuryRoutes.js');

  console.log('Done.');
}

run();
