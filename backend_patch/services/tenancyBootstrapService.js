const Company = require('../models/Company');

const DEFAULT_COMPANY_NAME =
  process.env.DEFAULT_COMPANY_NAME || 'شركة البحيرة العربية';
const DEFAULT_COMPANY_SLUG = process.env.DEFAULT_COMPANY_SLUG || 'albuhaira';

const isSystemCollection = (name) =>
  !name ||
  name.startsWith('system.') ||
  name.startsWith('tmp.') ||
  name === 'companies';

const ensureDefaultCompany = async () => {
  const existing = await Company.findOne({ isDefault: true });
  if (existing) return existing;

  const byName = await Company.findOne({ name: DEFAULT_COMPANY_NAME });
  if (byName) {
    byName.isDefault = true;
    if (!byName.slug) byName.slug = DEFAULT_COMPANY_SLUG;
    await byName.save();
    return byName;
  }

  return Company.create({
    name: DEFAULT_COMPANY_NAME,
    slug: DEFAULT_COMPANY_SLUG,
    isDefault: true,
  });
};

const migrateLegacyDocumentsToCompany = async ({ mongoose, companyId }) => {
  const db = mongoose.connection?.db;
  if (!db) return;

  const collections = await db.listCollections().toArray();
  for (const item of collections) {
    const name = item?.name;
    if (isSystemCollection(name)) continue;

    const collection = db.collection(name);
    await collection.updateMany(
      { $or: [{ companyId: { $exists: false } }, { companyId: null }] },
      { $set: { companyId } }
    );
  }
};

const bootstrapTenancy = async ({ mongoose }) => {
  const defaultCompany = await ensureDefaultCompany();
  await migrateLegacyDocumentsToCompany({
    mongoose,
    companyId: defaultCompany._id,
  });
  return defaultCompany;
};

module.exports = {
  bootstrapTenancy,
  ensureDefaultCompany,
  DEFAULT_COMPANY_NAME,
};

