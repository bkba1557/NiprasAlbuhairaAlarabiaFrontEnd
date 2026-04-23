const mongoose = require('mongoose');
const { getTenantCompanyId } = require('./tenantContext');

const hasOwn = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key);

const toObjectId = (value) => {
  if (!value) return null;
  try {
    return new mongoose.Types.ObjectId(String(value));
  } catch (e) {
    return null;
  }
};

module.exports = function tenantPlugin(schema) {
  if (schema?.options?.tenant === false) return;

  if (!schema.path('companyId')) {
    schema.add({
      companyId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Company',
        index: true,
        default: null,
      },
    });
  }

  const applyTenantFilter = function applyTenantFilter() {
    const companyId = getTenantCompanyId();
    if (!companyId) return;

    const query = typeof this.getQuery === 'function' ? this.getQuery() : null;
    if (query && hasOwn(query, 'companyId')) return;

    this.where({ companyId: toObjectId(companyId) || companyId });
  };

  schema.pre(/^find/, function tenantFindHook(next) {
    applyTenantFilter.call(this);
    next();
  });

  const mutatingQueryOps = [
    'update',
    'updateOne',
    'updateMany',
    'deleteOne',
    'deleteMany',
    'findOneAndUpdate',
    'findOneAndDelete',
    'findOneAndRemove',
    'replaceOne',
  ];

  mutatingQueryOps.forEach((op) => {
    schema.pre(op, function tenantWriteHook(next) {
      applyTenantFilter.call(this);
      next();
    });
  });

  schema.pre('aggregate', function tenantAggregateHook(next) {
    const companyId = getTenantCompanyId();
    if (!companyId) return next();

    const companyObjectId = toObjectId(companyId);
    if (!companyObjectId) return next();

    const pipeline = this.pipeline();
    const alreadyScoped = pipeline.some(
      (stage) => stage?.$match && hasOwn(stage.$match, 'companyId')
    );
    if (!alreadyScoped) {
      pipeline.unshift({ $match: { companyId: companyObjectId } });
    }

    next();
  });

  schema.pre('save', function tenantSaveHook(next) {
    const requestCompanyId = getTenantCompanyId();
    const defaultCompanyId = process.env.DEFAULT_COMPANY_ID || null;
    const effectiveCompanyId = requestCompanyId || defaultCompanyId;
    if (!effectiveCompanyId) return next();

    if (!this.companyId) {
      this.companyId = toObjectId(effectiveCompanyId) || effectiveCompanyId;
    }

    next();
  });
};
