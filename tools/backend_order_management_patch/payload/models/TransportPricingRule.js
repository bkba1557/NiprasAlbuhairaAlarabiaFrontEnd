const mongoose = require('mongoose');

const transportPricingRuleSchema = new mongoose.Schema(
  {
    sourceCity: {
      type: String,
      required: true,
      trim: true,
    },
    capacityLiters: {
      type: Number,
      required: true,
      enum: [20000, 32000],
    },
    fuelType: {
      type: String,
      required: true,
      enum: ['بنزين 91', 'بنزين 95', 'ديزل', 'كيروسين'],
      trim: true,
    },
    transportMode: {
      type: String,
      enum: ['fixed', 'per_liter'],
      default: 'fixed',
    },
    transportValue: {
      type: Number,
      required: true,
      min: 0,
    },
    returnMode: {
      type: String,
      enum: ['fixed', 'per_liter'],
      default: 'fixed',
    },
    returnValue: {
      type: Number,
      min: 0,
      default: 0,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    notes: {
      type: String,
      trim: true,
    },
  },
  { timestamps: true }
);

transportPricingRuleSchema.index(
  { sourceCity: 1, capacityLiters: 1, fuelType: 1 },
  { unique: true }
);

module.exports = mongoose.model('TransportPricingRule', transportPricingRuleSchema);
