const express = require('express');
const customerTreasuryController = require('../controllers/customerTreasuryController');
const { authMiddleware, financeManagerMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/branches', customerTreasuryController.getBranches);
router.post('/branches', financeManagerMiddleware, customerTreasuryController.createBranch);
router.put('/branches/:id', financeManagerMiddleware, customerTreasuryController.updateBranch);

router.get('/overview', customerTreasuryController.getOverview);

router.get('/receipts', customerTreasuryController.getReceipts);
router.post('/receipts', financeManagerMiddleware, customerTreasuryController.createReceipt);

router.get('/customers/:customerId/ledger', customerTreasuryController.getCustomerLedger);

module.exports = router;
