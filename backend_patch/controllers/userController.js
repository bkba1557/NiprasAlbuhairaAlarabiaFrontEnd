const bcrypt = require('bcryptjs');

const Driver = require('../models/Driver');
const Station = require('../models/Station');
const Supplier = require('../models/Supplier');
const User = require('../models/User');
const {
  ALL_PERMISSIONS,
  resolvePermissionsForRole,
} = require('../utils/rolePermissions');
const { uniqueStationIds } = require('../utils/stationAccess');

const ALLOWED_ROLES = [
  'owner',
  'owner_station',
  'admin',
  'manager',
  'supervisor',
  'maintenance',
  'maintenance_technician',
  'maintenance_station',
  'employee',
  'viewer',
  'station_boy',
  'sales_manager_statiun',
  'maintenance_car_management',
  'finance_manager',
  'driver',
  'movement',
  'archive',
  'supplier',
];

const normalizeRole = (role) => {
  if (typeof role !== 'string') return 'employee';
  return ALLOWED_ROLES.includes(role) ? role : 'employee';
};

const normalizePermissions = (permissions) => {
  if (!Array.isArray(permissions)) return [];
  return [...new Set(permissions)].filter((permission) =>
    ALL_PERMISSIONS.includes(permission)
  );
};

const applyRolePermissions = (role, permissions) => {
  const explicitPermissions = normalizePermissions(permissions);
  return resolvePermissionsForRole(role, explicitPermissions);
};

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();
const normalizeUsername = (value) => String(value || '').trim().toLowerCase();
const normalizePhone = (value) => String(value || '').trim().replace(/\s+/g, '');
const normalizeDriverId = (value) => {
  const normalized = String(value || '').trim();
  return normalized || null;
};
const normalizeSupplierId = (value) => {
  const normalized = String(value || '').trim();
  return normalized || null;
};

const serializeStationIds = (stationIds) =>
  uniqueStationIds(
    Array.isArray(stationIds)
      ? stationIds.map((station) =>
          station && typeof station === 'object' && station._id
            ? station._id
            : station
        )
      : []
  );

const serializeStationId = (stationId) =>
  stationId && typeof stationId === 'object' && stationId._id
    ? stationId._id.toString()
    : stationId?.toString() || null;

const serializeDriverId = (driverId) =>
  driverId && typeof driverId === 'object' && driverId._id
    ? driverId._id.toString()
    : driverId?.toString() || null;

const serializeSupplierId = (supplierId) =>
  supplierId && typeof supplierId === 'object' && supplierId._id
    ? supplierId._id.toString()
    : supplierId?.toString() || null;

const serializeUser = (user) => ({
  id: user._id,
  name: user.name,
  username: user.username || '',
  email: user.email,
  role: user.role,
  companyId: user.companyId ? user.companyId.toString() : null,
  company: user.company,
  phone: user.phone || '',
  stationId: serializeStationId(user.stationId),
  stationIds: serializeStationIds(user.stationIds),
  driverId: serializeDriverId(user.driverId),
  supplierId: serializeSupplierId(user.supplierId),
  isBlocked: Boolean(user.isBlocked),
  createdAt: user.createdAt,
  permissions: user.permissions || [],
});

const findExistingByField = async ({ field, value, excludeUserId }) => {
  if (!value) return null;

  const query = {
    [field]: value,
  };

  if (excludeUserId) {
    query._id = { $ne: excludeUserId };
  }

  return User.findOne(query).lean();
};

const resolveDriverAssignment = async (role, driverId) => {
  if (role !== 'driver') {
    return null;
  }

  const normalizedDriverId = normalizeDriverId(driverId);
  if (!normalizedDriverId) {
    throw new Error('Driver is required for driver users');
  }

  const driverExists = await Driver.exists({ _id: normalizedDriverId });
  if (!driverExists) {
    throw new Error('Invalid driver');
  }

  return normalizedDriverId;
};

exports.listUsers = async (req, res) => {
  try {
    let { page = 1, limit = 50, search, role, blocked } = req.query;

    page = Math.max(1, Number(page) || 1);
    const requestedLimit = Number(limit);
    const unlimited = Number.isFinite(requestedLimit) && requestedLimit <= 0;
    limit = unlimited ? 0 : Math.min(100, requestedLimit || 50);
    const filter = {};

    if (role && ALLOWED_ROLES.includes(role)) {
      filter.role = role;
    }

    if (blocked === 'true') {
      filter.isBlocked = true;
    } else if (blocked === 'false') {
      filter.isBlocked = false;
    }

    if (search && search.trim().length > 0) {
      const regex = new RegExp(search.trim(), 'i');
      filter.$or = [
        { name: regex },
        { username: regex },
        { email: regex },
        { company: regex },
        { phone: regex },
      ];
    }

    const skip = unlimited ? 0 : (page - 1) * limit;

    let usersQuery = User.find(filter)
      .select(
        'name username email role company phone stationId stationIds driverId supplierId createdAt isBlocked permissions'
      )
      .sort({ createdAt: -1 })
      .skip(skip);

    if (!unlimited) {
      usersQuery = usersQuery.limit(limit);
    }

    const [users, total] = await Promise.all([
      usersQuery.lean(),
      User.countDocuments(filter),
    ]);

    res.json({
      success: true,
      users: users.map(serializeUser),
      pagination: {
        total,
        page: unlimited ? 1 : page,
        limit: unlimited ? total : limit,
        pages: unlimited ? 1 : Math.max(1, Math.ceil(total / limit)),
      },
    });
  } catch (error) {
    console.error('User list error:', error);
    res.status(500).json({ success: false, error: 'Failed to load users' });
  }
};

exports.createUser = async (req, res) => {
  try {
    const {
      name,
      username,
      email,
      password,
      phone,
      role,
      permissions,
      stationId,
      stationIds,
      driverId,
      supplierId,
    } = req.body;

    const requesterCompanyId = req.user?.companyId ? req.user.companyId.toString() : '';
    const requesterCompanyName = String(req.user?.company || '').trim();

    if (!requesterCompanyId || !requesterCompanyName) {
      return res.status(403).json({
        success: false,
        error:
          'الحساب غير مرتبط بشركة. برجاء تشغيل ترحيل البيانات (tenancy migration) ثم إعادة المحاولة.',
      });
    }

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields',
      });
    }

    const normalizedEmail = normalizeEmail(email);
    const normalizedUsername = normalizeUsername(username);
    const normalizedPhone = normalizePhone(phone);

    const existingEmail = await findExistingByField({
      field: 'email',
      value: normalizedEmail,
    });
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        error: 'Email already in use',
      });
    }

    if (normalizedUsername) {
      const existingUsername = await findExistingByField({
        field: 'username',
        value: normalizedUsername,
      });
      if (existingUsername) {
        return res.status(409).json({
          success: false,
          error: 'Username already in use',
        });
      }
    }

    if (normalizedPhone) {
      const existingPhone = await findExistingByField({
        field: 'phone',
        value: normalizedPhone,
      });
      if (existingPhone) {
        return res.status(409).json({
          success: false,
          error: 'Phone already in use',
        });
      }
    }

    const finalRole = normalizeRole(role);
    let resolvedStationId = null;
    let resolvedStationIds = [];
    let resolvedSupplierId = null;

    if (finalRole === 'station_boy') {
      const normalizedStationId = uniqueStationIds([stationId])[0];
      if (!normalizedStationId) {
        return res.status(400).json({
          success: false,
          error: 'Station is required for station boy',
        });
      }

      const stationExists = await Station.exists({ _id: normalizedStationId });
      if (!stationExists) {
        return res.status(400).json({
          success: false,
          error: 'Invalid station',
        });
      }

      resolvedStationId = normalizedStationId;
    }

    if (finalRole === 'owner_station') {
      const normalizedStationIds = uniqueStationIds(stationIds);
      if (!normalizedStationIds.length) {
        return res.status(400).json({
          success: false,
          error: 'At least one station is required for station owner',
        });
      }

      const stationsCount = await Station.countDocuments({
        _id: { $in: normalizedStationIds },
      });

      if (stationsCount !== normalizedStationIds.length) {
        return res.status(400).json({
          success: false,
          error: 'Invalid station list',
        });
      }

      resolvedStationIds = normalizedStationIds;
    }

    let resolvedDriverId;
    try {
      resolvedDriverId = await resolveDriverAssignment(finalRole, driverId);
    } catch (error) {
      return res.status(400).json({ success: false, error: error.message });
    }

    if (finalRole === 'supplier') {
      const normalizedSupplierId = normalizeSupplierId(supplierId);
      if (!normalizedSupplierId) {
        return res.status(400).json({
          success: false,
          error: 'Supplier is required for supplier users',
        });
      }

      const supplierExists = await Supplier.exists({ _id: normalizedSupplierId });
      if (!supplierExists) {
        return res.status(400).json({
          success: false,
          error: 'Invalid supplier',
        });
      }

      resolvedSupplierId = normalizedSupplierId;
    }

    const user = new User({
      name: String(name).trim(),
      username: normalizedUsername || undefined,
      email: normalizedEmail,
      password,
      companyId: req.user.companyId,
      company: requesterCompanyName,
      phone: normalizedPhone || null,
      role: finalRole,
      permissions: applyRolePermissions(finalRole, permissions),
      stationId: resolvedStationId,
      stationIds: resolvedStationIds,
      driverId: resolvedDriverId,
      supplierId: resolvedSupplierId,
    });

    await user.save();

    res.status(201).json({
      success: true,
      user: serializeUser(user),
    });
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create user',
    });
  }
};

exports.updateUser = async (req, res) => {
  try {
    const userId = req.params.id;
    const {
      name,
      username,
      email,
      phone,
      role,
      password,
      permissions,
      stationId,
      stationIds,
      driverId,
      supplierId,
    } = req.body;

    const updates = {};

    if (name !== undefined) updates.name = name;
    if (email !== undefined) updates.email = normalizeEmail(email);
    if (username !== undefined) {
      updates.username = normalizeUsername(username) || undefined;
    }
    if (phone !== undefined) updates.phone = normalizePhone(phone) || null;

    let finalRole;
    if (role !== undefined) {
      finalRole = normalizeRole(role);
      updates.role = finalRole;
    }

    if (password) {
      const salt = await bcrypt.genSalt(10);
      updates.password = await bcrypt.hash(password, salt);
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    if (email !== undefined) {
      const duplicateEmail = await findExistingByField({
        field: 'email',
        value: updates.email,
        excludeUserId: userId,
      });
      if (duplicateEmail) {
        return res.status(409).json({
          success: false,
          error: 'Email already in use',
        });
      }
    }

    if (username !== undefined && updates.username) {
      const duplicateUsername = await findExistingByField({
        field: 'username',
        value: updates.username,
        excludeUserId: userId,
      });
      if (duplicateUsername) {
        return res.status(409).json({
          success: false,
          error: 'Username already in use',
        });
      }
    }

    if (phone !== undefined && updates.phone) {
      const duplicatePhone = await findExistingByField({
        field: 'phone',
        value: updates.phone,
        excludeUserId: userId,
      });
      if (duplicatePhone) {
        return res.status(409).json({
          success: false,
          error: 'Phone already in use',
        });
      }
    }

    const effectiveRole = finalRole || user.role;
    const normalizedStationId = uniqueStationIds([stationId])[0];
    const normalizedStationIds = uniqueStationIds(stationIds);
    const normalizedSupplierId = normalizeSupplierId(supplierId);

    if (effectiveRole === 'station_boy') {
      if (!normalizedStationId) {
        return res.status(400).json({
          success: false,
          error: 'Station is required for station boy',
        });
      }

      const stationExists = await Station.exists({ _id: normalizedStationId });
      if (!stationExists) {
        return res.status(400).json({
          success: false,
          error: 'Invalid station',
        });
      }

      updates.stationId = normalizedStationId;
      updates.stationIds = [];
    } else if (effectiveRole === 'owner_station') {
      if (!normalizedStationIds.length) {
        return res.status(400).json({
          success: false,
          error: 'At least one station is required for station owner',
        });
      }

      const stationsCount = await Station.countDocuments({
        _id: { $in: normalizedStationIds },
      });

      if (stationsCount !== normalizedStationIds.length) {
        return res.status(400).json({
          success: false,
          error: 'Invalid station list',
        });
      }

      updates.stationId = null;
      updates.stationIds = normalizedStationIds;
    } else {
      updates.stationId = null;
      updates.stationIds = [];
    }

    try {
      updates.driverId = await resolveDriverAssignment(effectiveRole, driverId);
    } catch (error) {
      return res.status(400).json({ success: false, error: error.message });
    }

    if (effectiveRole === 'supplier') {
      if (!normalizedSupplierId) {
        return res.status(400).json({
          success: false,
          error: 'Supplier is required for supplier users',
        });
      }

      const supplierExists = await Supplier.exists({ _id: normalizedSupplierId });
      if (!supplierExists) {
        return res.status(400).json({
          success: false,
          error: 'Invalid supplier',
        });
      }

      updates.supplierId = normalizedSupplierId;
    } else {
      updates.supplierId = null;
    }

    if (permissions !== undefined || effectiveRole === 'driver') {
      updates.permissions = applyRolePermissions(effectiveRole, permissions);
    }

    const updatedUser = await User.findByIdAndUpdate(userId, updates, {
      new: true,
      runValidators: true,
    }).select(
      'name username email role company phone stationId stationIds driverId supplierId createdAt isBlocked permissions'
    );

    res.json({ success: true, user: serializeUser(updatedUser) });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update user',
    });
  }
};

exports.deleteUser = async (req, res) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ success: false, error: 'Failed to delete user' });
  }
};

exports.blockUser = async (req, res) => {
  try {
    const { block } = req.body;

    if (typeof block !== 'boolean') {
      return res
        .status(400)
        .json({ success: false, error: 'Invalid block flag' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    user.isBlocked = block;
    await user.save();

    res.json({
      success: true,
      user: serializeUser(user),
    });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ success: false, error: 'Failed to update user' });
  }
};
