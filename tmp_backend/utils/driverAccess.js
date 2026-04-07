const Driver = require('../models/Driver');
const User = require('../models/User');

const DRIVER_ASSIGNED_ONLY_PERMISSION = 'orders_view_assigned_only';
const DRIVER_HIDDEN_ORDER_STATUSES = ['ملغى', 'مكتمل', 'تم التنفيذ'];

const asIdString = (value) => {
  if (!value) return null;

  if (typeof value === 'object' && value._id) {
    return String(value._id);
  }

  const stringValue = String(value).trim();
  return stringValue || null;
};

const normalizeOrderStatus = (status) => String(status || '').trim();

const isDriverHiddenOrderStatus = (status) =>
  DRIVER_HIDDEN_ORDER_STATUSES.includes(normalizeOrderStatus(status));

const userRequiresAssignedOrdersOnly = (user) => {
  if (!user) return false;

  return String(user.role || '').trim().toLowerCase() === 'driver';
};

const resolveLinkedDriverId = async (user) => {
  if (!user) return null;

  const directDriverId = asIdString(user.driverId);
  if (directDriverId) {
    return directDriverId;
  }

  const phone = String(user.phone || '').trim();
  if (!phone) {
    return null;
  }

  const driver = await Driver.findOne({ phone }).select('_id').lean();
  return asIdString(driver?._id);
};

const buildAssignedOrdersFilter = (driverId, { includeHistory = false } = {}) => {
  const normalizedDriverId = asIdString(driverId);
  if (!normalizedDriverId) {
    return {
      _id: {
        $exists: false,
      },
    };
  }

  if (includeHistory) {
    return {
      driver: normalizedDriverId,
    };
  }

  return {
    $and: [
      { driver: normalizedDriverId },
      { status: { $nin: DRIVER_HIDDEN_ORDER_STATUSES } },
    ],
  };
};

const userCanAccessOrder = async (user, orderOrDriverId) => {
  if (!userRequiresAssignedOrdersOnly(user)) {
    return true;
  }

  const linkedDriverId = await resolveLinkedDriverId(user);
  if (!linkedDriverId) {
    return false;
  }

  const orderDriverId = asIdString(orderOrDriverId?.driver || orderOrDriverId);
  if (!(orderDriverId && orderDriverId === linkedDriverId)) {
    return false;
  }

  return true;
};

const findDriverRecipients = async (driverId) => {
  const normalizedDriverId = asIdString(driverId);
  if (!normalizedDriverId) {
    return [];
  }

  const driver = await Driver.findById(normalizedDriverId).select('phone').lean();
  const driverPhone = String(driver?.phone || '').trim();

  const query = {
    isBlocked: { $ne: true },
    $or: [{ driverId: normalizedDriverId }],
  };

  if (driverPhone) {
    query.$or.push({ role: 'driver', phone: driverPhone });
  }

  const users = await User.find(query).select('_id').lean();

  return [...new Set(users.map((user) => asIdString(user._id)).filter(Boolean))];
};

module.exports = {
  DRIVER_ASSIGNED_ONLY_PERMISSION,
  DRIVER_HIDDEN_ORDER_STATUSES,
  asIdString,
  buildAssignedOrdersFilter,
  findDriverRecipients,
  isDriverHiddenOrderStatus,
  resolveLinkedDriverId,
  userCanAccessOrder,
  userRequiresAssignedOrdersOnly,
};
