const TransportPricingRule = require('../models/TransportPricingRule');

const parseNumber = (value, fallback = null) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const parseInteger = (value, fallback = null) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeString = (value) => {
  const text = String(value || '').trim();
  return text || null;
};

const escapeRegex = (value) =>
  String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const parseJsonObject = (value) => {
  if (!value) return null;
  if (typeof value === 'string') {
    const text = value.trim();
    if (!text) return null;
    try {
      const parsed = JSON.parse(text);
      return parsed && typeof parsed === 'object' ? parsed : null;
    } catch (_) {
      return null;
    }
  }
  return value && typeof value === 'object' ? value : null;
};

const normalizeMode = (value, fallback = 'fixed') => {
  return value === 'per_liter' ? 'per_liter' : fallback;
};

const getCustomerFuelPrice = (customer, fuelType) => {
  const normalizedFuelType = normalizeString(fuelType);
  if (!customer || !normalizedFuelType) return null;

  const entries = Array.isArray(customer.fuelPricing) ? customer.fuelPricing : [];
  const matchedEntry = entries.find((entry) => {
    return normalizeString(entry && entry.fuelType) === normalizedFuelType;
  });

  if (matchedEntry) {
    const matchedPrice = parseNumber(matchedEntry.pricePerLiter);
    if (matchedPrice !== null) return matchedPrice;
  }

  const legacyFuelPrice = parseNumber(customer.fuelPricePerLiter);
  return legacyFuelPrice !== null ? legacyFuelPrice : null;
};

const normalizeTransportOverride = (value) => {
  const payload = parseJsonObject(value);
  if (!payload) return null;

  const transportValue = parseNumber(payload.transportValue);
  if (transportValue === null) return null;

  return {
    sourceCity: normalizeString(payload.sourceCity),
    capacityLiters: parseInteger(payload.capacityLiters),
    fuelType: normalizeString(payload.fuelType),
    transportMode: normalizeMode(payload.transportMode, 'fixed'),
    transportValue,
    returnMode: normalizeMode(payload.returnMode, 'fixed'),
    returnValue: parseNumber(payload.returnValue, 0) || 0,
  };
};

const findTransportRule = async ({ fuelType, sourceCity, capacityLiters }) => {
  const normalizedFuelType = normalizeString(fuelType);
  const normalizedSourceCity = normalizeString(sourceCity);
  if (!normalizedFuelType || !normalizedSourceCity || !capacityLiters) return null;

  return TransportPricingRule.findOne({
    fuelType: normalizedFuelType,
    capacityLiters,
    isActive: true,
    sourceCity: new RegExp('^' + escapeRegex(normalizedSourceCity) + '$', 'i'),
  })
    .sort({ updatedAt: -1 })
    .lean();
};

async function buildCustomerOrderPricing({ customer, payload }) {
  if (!customer) {
    throw new Error('العميل غير موجود');
  }

  const requestType = normalizeString(payload.requestType) || 'شراء';
  const quantity = Math.max(0, parseNumber(payload.quantity, 0) || 0);
  const fuelType = normalizeString(payload.fuelType) || 'ديزل';
  const vatRate = Math.max(0, parseNumber(payload.vatRate, 0.15) || 0.15);

  const fuelPricePerLiter = getCustomerFuelPrice(customer, fuelType);
  if (fuelPricePerLiter === null) {
    throw new Error('لم يتم ضبط سعر الوقود لهذا العميل');
  }

  const fuelSubtotal = fuelPricePerLiter * quantity;

  let transportSourceCity = normalizeString(payload.transportSourceCity);
  let transportCapacityLiters = parseInteger(payload.transportCapacityLiters);
  let transportPricingOverride = null;
  let transportMode = null;
  let transportValue = null;
  let returnMode = null;
  let returnValue = 0;
  let transportCharge = 0;
  let returnCharge = 0;
  let usedManualTransportOverride = false;
  let usedTransportRule = false;

  if (requestType === 'نقل') {
    transportPricingOverride = normalizeTransportOverride(
      payload.transportPricingOverride
    );

    if (transportPricingOverride) {
      usedManualTransportOverride = true;
      transportSourceCity = transportPricingOverride.sourceCity || transportSourceCity;
      transportCapacityLiters =
        transportPricingOverride.capacityLiters || transportCapacityLiters;
      transportMode = transportPricingOverride.transportMode;
      transportValue = transportPricingOverride.transportValue;
      returnMode = transportPricingOverride.returnMode;
      returnValue = transportPricingOverride.returnValue;
    } else {
      const matchedRule = await findTransportRule({
        fuelType,
        sourceCity: transportSourceCity,
        capacityLiters: transportCapacityLiters,
      });

      if (!matchedRule) {
        throw new Error('لا توجد تسعيرة نقل مطابقة لهذه المدينة والسعة ونوع الوقود');
      }

      usedTransportRule = true;
      transportSourceCity = normalizeString(matchedRule.sourceCity) || transportSourceCity;
      transportCapacityLiters =
        parseInteger(matchedRule.capacityLiters) || transportCapacityLiters;
      transportMode = matchedRule.transportMode || 'fixed';
      transportValue = parseNumber(matchedRule.transportValue, 0) || 0;
      returnMode = matchedRule.returnMode || 'fixed';
      returnValue = parseNumber(matchedRule.returnValue, 0) || 0;
    }

    if (transportValue === null) {
      throw new Error('تسعيرة النقل لهذا الطلب غير مكتملة');
    }

    transportCharge =
      transportMode === 'per_liter' ? transportValue * quantity : transportValue;
    returnCharge = returnMode === 'per_liter' ? returnValue * quantity : returnValue;
  } else {
    transportSourceCity = null;
    transportCapacityLiters = null;
  }

  const subtotal = fuelSubtotal + transportCharge + returnCharge;
  const unitPricePerLiter = quantity > 0 ? subtotal / quantity : 0;
  const vatAmount = subtotal * vatRate;
  const totalWithVat = subtotal + vatAmount;

  const pricingSnapshot = {
    requestType,
    fuelType,
    quantity,
    fuelPricePerLiter,
    fuelSubtotal,
    transportCharge,
    returnCharge,
    subtotal,
    unitPricePerLiter,
    vatRate,
    vatAmount,
    totalWithVat,
    totalPriceWithVat: totalWithVat,
    sourceCity: requestType === 'نقل' ? transportSourceCity : null,
    capacityLiters: requestType === 'نقل' ? transportCapacityLiters : null,
    transportMode: requestType === 'نقل' ? transportMode : null,
    transportValue: requestType === 'نقل' ? transportValue : null,
    returnMode: requestType === 'نقل' ? returnMode : null,
    returnValue: requestType === 'نقل' ? returnValue : null,
    usedManualTransportOverride,
    usedTransportRule,
  };

  return {
    unitPrice: unitPricePerLiter,
    totalPrice: subtotal,
    vatRate,
    vatAmount,
    totalPriceWithVat: totalWithVat,
    transportSourceCity: requestType === 'نقل' ? transportSourceCity : null,
    transportCapacityLiters: requestType === 'نقل' ? transportCapacityLiters : null,
    pricingSnapshot,
    transportPricingOverride:
      requestType === 'نقل' && transportPricingOverride ? transportPricingOverride : null,
  };
}

module.exports = {
  buildCustomerOrderPricing,
};
