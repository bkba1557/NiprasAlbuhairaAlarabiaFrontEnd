const express = require('express');
const router = express.Router();
const qualificationStationController = require(
  '../controllers/qualificationStationController'
);
const {
  authMiddleware,
  ownerOnlyMiddleware,
} = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.get('/', qualificationStationController.getQualificationStations);
router.get('/:id', qualificationStationController.getQualificationStation);
router.post('/', qualificationStationController.createQualificationStation);
router.put('/:id', qualificationStationController.updateQualificationStation);
router.put('/:id/status', qualificationStationController.updateStatus);
router.delete(
  '/:id',
  ownerOnlyMiddleware,
  qualificationStationController.deleteQualificationStation
);

module.exports = router;
