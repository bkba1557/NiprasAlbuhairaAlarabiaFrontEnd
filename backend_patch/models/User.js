const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  username: {
    type: String,
    trim: true,
    lowercase: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  password: {
    type: String,
    required: true,
  },
  role: {
    type: String,
    enum: [
      'owner',
      'owner_station',
      'admin',
      'manager',
      'supervisor',
      'maintenance',
      'employee',
      'maintenance_technician',
      'maintenance_station',
      'viewer',
      'station_boy',
      'sales_manager_statiun',
      'maintenance_car_management',
      'finance_manager',
      'driver',
      'movement',
      'archive',
      'supplier',
    ],
    default: 'employee',
  },
  isBlocked: {
    type: Boolean,
    default: false,
  },
  stationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Station',
    default: null,
  },
  stationIds: {
    type: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Station',
      },
    ],
    default: [],
  },
  driverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Driver',
    default: null,
    index: true,
  },
  supplierId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Supplier',
    default: null,
    index: true,
  },
  permissions: {
    type: [String],
    default: [],
  },
  companyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Company',
    default: null,
    index: true,
  },
  company: {
    type: String,
    required: true,
  },
  phone: {
    type: String,
  },
  authVersion: {
    type: Number,
    default: 0,
    min: 0,
  },
  loginOtpCodeHash: { type: String },
  loginOtpExpiresAt: { type: Date },
  loginOtpRequestedAt: { type: Date },
  loginOtpDeviceId: { type: String, trim: true },
  lastLoginAt: { type: Date },
  isOnline: {
    type: Boolean,
    default: false,
    index: true,
  },
  lastSeenAt: {
    type: Date,
    default: Date.now,
  },
  lastWelcomeEmailAt: { type: Date },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

userSchema.pre('save', async function saveHook(next) {
  if (this.isModified('email') && this.email) {
    this.email = String(this.email).trim().toLowerCase();
  }

  if (this.isModified('username')) {
    this.username = this.username
      ? String(this.username).trim().toLowerCase()
      : undefined;
  }

  if (this.isModified('phone') && this.phone) {
    this.phone = String(this.phone).trim();
  }

  if (!this.isModified('password')) return next();

  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

userSchema.methods.comparePassword = async function comparePassword(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
