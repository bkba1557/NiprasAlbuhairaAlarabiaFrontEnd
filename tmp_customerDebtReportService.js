const moment = require('moment');

const CustomerDebtCollection = require('../models/CustomerDebtCollection');
const CustomerDebtSnapshot = require('../models/CustomerDebtSnapshot');

const RIYADH_UTC_OFFSET_MINUTES = 180;

const toRiyadhStartOfDay = (dateStr) =>
  moment(dateStr).utcOffset(RIYADH_UTC_OFFSET_MINUTES).startOf('day').toDate();

const toRiyadhEndOfDay = (dateStr) =>
  moment(dateStr).utcOffset(RIYADH_UTC_OFFSET_MINUTES).endOf('day').toDate();

const normalizeDateOnly = (value) => String(value || '').trim().slice(0, 10);

const buildDateRangeQuery = ({ startDate, endDate }) => {
  const start = normalizeDateOnly(startDate);
  const end = normalizeDateOnly(endDate);
  if (!start && !end) return null;

  const from = start ? toRiyadhStartOfDay(start) : null;
  const to = end ? toRiyadhEndOfDay(end) : null;

  if (from && to) return { $gte: from, $lte: to };
  if (from) return { $gte: from };
  if (to) return { $lte: to };
  return null;
};

const sumTotals = (collections) =>
  collections.reduce(
    (acc, item) => {
      const amount = Number(item.amount || 0);
      acc.count += 1;
      acc.total += amount;
      if (item.paymentMethod === 'cash') acc.cash += amount;
      if (item.paymentMethod === 'card') acc.card += amount;
      if (item.paymentMethod === 'bank_transfer') acc.bankTransfer += amount;
      return acc;
    },
    { count: 0, total: 0, cash: 0, card: 0, bankTransfer: 0 },
  );

exports.getCustomerDebtCollectionsReport = async ({
  startDate,
  endDate,
  customerAccountNumber,
  collectorId,
  source,
}) => {
  const query = {};
  const range = buildDateRangeQuery({ startDate, endDate });
  if (range) query.createdAt = range;
  if (customerAccountNumber) {
    query.customerAccountNumber = String(customerAccountNumber).trim();
  }
  if (collectorId) query.collectorId = collectorId;
  if (source) query.source = String(source).trim();

  const collections = await CustomerDebtCollection.find(query)
    .sort({ createdAt: 1 })
    .lean();

  return {
    collections,
    summary: sumTotals(collections),
  };
};

exports.getCustomerDebtLedgerReport = async ({ customerAccountNumber }) => {
  const account = String(customerAccountNumber || '').trim();
  if (!account) {
    const error = new Error('customerAccountNumber is required');
    error.statusCode = 400;
    throw error;
  }

  const snapshot = await CustomerDebtSnapshot.findOne({}).sort({ importedAt: -1 }).lean();
  if (!snapshot) {
    const error = new Error('No snapshot imported');
    error.statusCode = 400;
    throw error;
  }

  const snapshotRow = (snapshot.rows || []).find((row) => row.accountNumber === account);
  if (!snapshotRow) {
    const error = new Error('Customer not found in latest snapshot');
    error.statusCode = 404;
    throw error;
  }

  const collections = await CustomerDebtCollection.find({
    customerAccountNumber: account,
  })
    .sort({ createdAt: 1 })
    .lean();

  const totals = sumTotals(collections);
  const openingBalance = Number(snapshotRow.netBalance || 0);
  const currentBalance = openingBalance - totals.total;

  return {
    customerAccountNumber: account,
    customerName: snapshotRow.customerName,
    openingBalance,
    totalCollected: totals.total,
    currentBalance,
    collections,
    summary: totals,
  };
};

