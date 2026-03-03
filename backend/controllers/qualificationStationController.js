const QualificationStation = require('../models/QualificationStation');

const ALLOWED_STATUS = ['qualified', 'unqualified'];

const buildSearchFilter = (search) => {
  if (!search) return {};
  return {
    $or: [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { region: new RegExp(search, 'i') },
      { address: new RegExp(search, 'i') },
    ],
  };
};

const normalizeStatus = (value) => {
  if (!value) return undefined;
  const normalized = value.toString().trim().toLowerCase();
  return ALLOWED_STATUS.includes(normalized) ? normalized : undefined;
};

const normalizeLocation = (location) => {
  if (!location) return undefined;
  const lat = Number(location.lat);
  const lng = Number(location.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return undefined;
  }
  return { lat, lng };
};

exports.getQualificationStations = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, status, city, region } = req.query;
    const skip = (Number(page) - 1) * Number(limit);
    const filter = { ...buildSearchFilter(search) };

    const normalizedStatus = normalizeStatus(status);
    if (normalizedStatus) filter.status = normalizedStatus;
    if (city) filter.city = city;
    if (region) filter.region = region;

    const stations = await QualificationStation.find(filter)
      .populate('createdBy', 'name email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit))
      .lean();

    const mapped = stations.map((station) => ({
      ...station,
      createdByName: station.createdBy?.name,
    }));

    const total = await QualificationStation.countDocuments(filter);

    res.json({
      stations: mapped,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        pages: Math.ceil(total / Number(limit)),
      },
    });
  } catch (error) {
    console.error('getQualificationStations error:', error);
    res.status(500).json({ error: 'تعذر تحميل المحطات' });
  }
};

exports.getQualificationStation = async (req, res) => {
  try {
    const station = await QualificationStation.findById(req.params.id)
      .populate('createdBy', 'name email')
      .lean();

    if (!station) {
      return res.status(404).json({ error: 'المحطة غير موجودة' });
    }

    res.json({
      station: {
        ...station,
        createdByName: station.createdBy?.name,
      },
    });
  } catch (error) {
    console.error('getQualificationStation error:', error);
    res.status(500).json({ error: 'تعذر تحميل بيانات المحطة' });
  }
};

exports.createQualificationStation = async (req, res) => {
  try {
    const { name, city, region, address } = req.body;

    if (!name || !city || !region || !address) {
      return res.status(400).json({
        error: 'يرجى إدخال اسم المحطة والمدينة والمنطقة والعنوان',
      });
    }

    const location = normalizeLocation(req.body.location);
    if (!location) {
      return res.status(400).json({ error: 'يرجى تحديد موقع المحطة' });
    }

    const status = normalizeStatus(req.body.status) || 'unqualified';

    const station = new QualificationStation({
      name: name.trim(),
      city: city.trim(),
      region: region.trim(),
      address: address.trim(),
      status,
      location,
      notes: req.body.notes || '',
      createdBy: req.user._id,
    });

    await station.save();

    res.status(201).json({
      message: 'تم إنشاء محطة تأهيل جديدة',
      station: {
        ...station.toObject(),
        createdByName: req.user?.name,
      },
    });
  } catch (error) {
    console.error('createQualificationStation error:', error);
    res.status(400).json({ error: error.message || 'تعذر إنشاء المحطة' });
  }
};

exports.updateQualificationStation = async (req, res) => {
  try {
    const station = await QualificationStation.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ error: 'المحطة غير موجودة' });
    }

    const updates = { ...req.body };
    if (updates.status) {
      const normalized = normalizeStatus(updates.status);
      if (!normalized) {
        return res.status(400).json({ error: 'حالة المحطة غير صحيحة' });
      }
      updates.status = normalized;
    }
    if (updates.location) {
      const normalizedLocation = normalizeLocation(updates.location);
      if (!normalizedLocation) {
        return res.status(400).json({ error: 'موقع المحطة غير صحيح' });
      }
      updates.location = normalizedLocation;
    }

    Object.assign(station, updates);
    await station.save();

    res.json({
      message: 'تم تحديث بيانات المحطة',
      station: {
        ...station.toObject(),
        createdByName: station.createdBy?.name,
      },
    });
  } catch (error) {
    console.error('updateQualificationStation error:', error);
    res.status(400).json({ error: error.message || 'تعذر تحديث المحطة' });
  }
};

exports.updateStatus = async (req, res) => {
  try {
    const station = await QualificationStation.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ error: 'المحطة غير موجودة' });
    }

    const status = normalizeStatus(req.body.status);
    if (!status) {
      return res.status(400).json({ error: 'حالة المحطة غير صحيحة' });
    }

    station.status = status;
    await station.save();

    res.json({
      message: 'تم تحديث حالة المحطة',
      station,
    });
  } catch (error) {
    console.error('updateQualificationStatus error:', error);
    res.status(400).json({ error: error.message || 'تعذر تحديث الحالة' });
  }
};

exports.deleteQualificationStation = async (req, res) => {
  try {
    const station = await QualificationStation.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ error: 'المحطة غير موجودة' });
    }

    await QualificationStation.deleteOne({ _id: station._id });
    res.json({ message: 'تم حذف المحطة' });
  } catch (error) {
    console.error('deleteQualificationStation error:', error);
    res.status(500).json({ error: 'تعذر حذف المحطة' });
  }
};
