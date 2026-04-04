const mongoose = require('mongoose');
const TransportPricingRule = require('../models/TransportPricingRule');

const cleanText = (value) => String(value || '').trim();

const parseNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const parseInteger = (value) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
};

const parseBoolean = (value, fallback = true) => {
  if (typeof value === 'boolean') return value;
  if (value === 'true') return true;
  if (value === 'false') return false;
  return fallback;
};

const buildPayload = (body) => {
  const sourceCity = cleanText(body.sourceCity);
  const capacityLiters = parseInteger(body.capacityLiters);
  const fuelType = cleanText(body.fuelType);
  const transportMode = body.transportMode === 'per_liter' ? 'per_liter' : 'fixed';
  const transportValue = parseNumber(body.transportValue);
  const returnMode = body.returnMode === 'per_liter' ? 'per_liter' : 'fixed';
  const returnValue = parseNumber(body.returnValue);

  if (!sourceCity) throw new Error('مدينة المصدر مطلوبة');
  if (![20000, 32000].includes(capacityLiters)) {
    throw new Error('السعة يجب أن تكون 20000 أو 32000');
  }
  if (!['بنزين 91', 'بنزين 95', 'ديزل', 'كيروسين'].includes(fuelType)) {
    throw new Error('نوع الوقود غير صالح');
  }
  if (transportValue === null || transportValue < 0) {
    throw new Error('قيمة النقل غير صحيحة');
  }
  if (returnValue === null || returnValue < 0) {
    throw new Error('قيمة الرد غير صحيحة');
  }

  return {
    sourceCity,
    capacityLiters,
    fuelType,
    transportMode,
    transportValue,
    returnMode,
    returnValue,
    isActive: parseBoolean(body.isActive, true),
    notes: cleanText(body.notes) || undefined,
  };
};

exports.getRules = async (req, res) => {
  try {
    const filter = {};

    if (req.query.sourceCity) {
      filter.sourceCity = new RegExp(cleanText(req.query.sourceCity), 'i');
    }

    if (req.query.fuelType) {
      filter.fuelType = cleanText(req.query.fuelType);
    }

    if (req.query.capacityLiters) {
      const capacityLiters = parseInteger(req.query.capacityLiters);
      if (capacityLiters) {
        filter.capacityLiters = capacityLiters;
      }
    }

    if (req.query.isActive === 'true' || req.query.isActive === 'false') {
      filter.isActive = req.query.isActive === 'true';
    }

    if (req.query.q) {
      const regex = new RegExp(cleanText(req.query.q), 'i');
      filter.$or = [{ sourceCity: regex }, { notes: regex }, { fuelType: regex }];
    }

    const rules = await TransportPricingRule.find(filter)
      .sort({ isActive: -1, sourceCity: 1, capacityLiters: 1, fuelType: 1 })
      .lean();

    return res.json({ success: true, rules });
  } catch (error) {
    console.error('getRules error:', error);
    return res.status(500).json({ error: 'حدث خطأ أثناء جلب تسعيرة النقل' });
  }
};

exports.createRule = async (req, res) => {
  try {
    const payload = buildPayload(req.body);
    const rule = await TransportPricingRule.create(payload);
    return res.status(201).json({ success: true, rule });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(409).json({
        error: 'يوجد تسعير مسجل مسبقاً لنفس المدينة والسعة ونوع الوقود',
      });
    }
    return res.status(400).json({ error: error.message || 'تعذر حفظ التسعير' });
  }
};

exports.updateRule = async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: 'معرف التسعير غير صالح' });
    }

    const payload = buildPayload(req.body);
    const rule = await TransportPricingRule.findByIdAndUpdate(
      req.params.id,
      payload,
      { new: true, runValidators: true }
    );

    if (!rule) {
      return res.status(404).json({ error: 'التسعير غير موجود' });
    }

    return res.json({ success: true, rule });
  } catch (error) {
    if (error?.code === 11000) {
      return res.status(409).json({
        error: 'يوجد تسعير مسجل مسبقاً لنفس المدينة والسعة ونوع الوقود',
      });
    }
    return res.status(400).json({ error: error.message || 'تعذر تحديث التسعير' });
  }
};

exports.deleteRule = async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: 'معرف التسعير غير صالح' });
    }

    const deleted = await TransportPricingRule.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res.status(404).json({ error: 'التسعير غير موجود' });
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('deleteRule error:', error);
    return res.status(500).json({ error: 'تعذر حذف التسعير' });
  }
};
