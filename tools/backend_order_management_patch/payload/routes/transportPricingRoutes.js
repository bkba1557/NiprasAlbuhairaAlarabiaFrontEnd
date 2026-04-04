const express = require('express');
const transportPricingController = require('../controllers/transportPricingController');
const { authMiddleware, financeManagerMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', transportPricingController.getRules);
router.post('/', financeManagerMiddleware, transportPricingController.createRule);
router.put('/:id', financeManagerMiddleware, transportPricingController.updateRule);
router.delete('/:id', financeManagerMiddleware, transportPricingController.deleteRule);

module.exports = router;
