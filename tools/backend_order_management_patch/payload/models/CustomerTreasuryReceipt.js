const mongoose = require('mongoose');

const customerTreasuryReceiptSchema = new mongoose.Schema(
  {
    voucherNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CustomerTreasuryBranch',
      required: true,
      index: true,
    },
    branchName: {
      type: String,
      required: true,
      trim: true,
    },
    branchCode: {
      type: String,
      trim: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Customer',
      required: true,
      index: true,
    },
    customerName: {
      type: String,
      required: true,
      trim: true,
    },
    customerCode: {
      type: String,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    paymentMethod: {
      type: String,
      enum: ['نقداً', 'تحويل بنكي', 'شبكة', 'شيك'],
      default: 'نقداً',
    },
    notes: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ['posted', 'cancelled'],
      default: 'posted',
    },
    receivedAt: {
      type: Date,
      default: Date.now,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    createdByName: {
      type: String,
      trim: true,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    versionKey: false,
  }
);

customerTreasuryReceiptSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  if (!this.createdAt) {
    this.createdAt = this.receivedAt || new Date();
  }
  next();
});

customerTreasuryReceiptSchema.index({ branchId: 1, createdAt: -1 });
customerTreasuryReceiptSchema.index({ customerId: 1, createdAt: -1 });

module.exports = mongoose.model(
  'CustomerTreasuryReceipt',
  customerTreasuryReceiptSchema
);
