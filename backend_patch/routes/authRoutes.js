const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const authController = require('../controllers/authController');
const {
  authMiddleware,
  adminOrOwnerMiddleware,
  ownerOnlyMiddleware,
} = require('../middleware/authMiddleware');

const registerValidation = [
  body('name').notEmpty().withMessage('الاسم مطلوب'),
  body('username')
    .optional({ values: 'falsy' })
    .isLength({ min: 3, max: 30 })
    .withMessage('اسم المستخدم يجب أن يكون بين 3 و30 حرفاً')
    .matches(/^\S+$/)
    .withMessage('اسم المستخدم يجب ألا يحتوي على مسافات'),
  body('email').isEmail().withMessage('بريد إلكتروني غير صالح'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
  body('company').notEmpty().withMessage('اسم الشركة مطلوب'),
];

const loginValidation = [
  body('email').isEmail().withMessage('بريد إلكتروني غير صالح'),
  body('password').notEmpty().withMessage('كلمة المرور مطلوبة'),
];

const otpRequestValidation = [
  body('loginType')
    .isIn(['email', 'phone', 'username'])
    .withMessage('طريقة تسجيل الدخول غير صحيحة'),
  body('identifier').trim().notEmpty().withMessage('بيانات الدخول مطلوبة'),
  body('deviceId').optional().isString(),
  body('deviceName').optional().isString(),
  body('platform').optional().isString(),
];

const otpVerifyValidation = [
  body('loginType')
    .isIn(['email', 'phone', 'username'])
    .withMessage('طريقة تسجيل الدخول غير صحيحة'),
  body('identifier').trim().notEmpty().withMessage('بيانات الدخول مطلوبة'),
  body('otp')
    .isLength({ min: 6, max: 6 })
    .withMessage('رمز التحقق يجب أن يتكون من 6 أرقام')
    .isNumeric()
    .withMessage('رمز التحقق يجب أن يتكون من أرقام فقط'),
  body('deviceId').optional().isString(),
  body('deviceName').optional().isString(),
  body('platform').optional().isString(),
];

const deviceBlockValidation = [
  body('reason').optional({ values: 'falsy' }).isString(),
];

router.post('/register', registerValidation, authController.register);
router.post('/login', loginValidation, authController.login);
router.post(
  '/request-login-otp',
  otpRequestValidation,
  authController.requestLoginOtp
);
router.post(
  '/verify-login-otp',
  otpVerifyValidation,
  authController.verifyLoginOtp
);
router.post('/logout', authMiddleware, authController.logoutCurrentSession);
router.get('/profile', authMiddleware, authController.getProfile);
router.get(
  '/devices',
  authMiddleware,
  ownerOnlyMiddleware,
  authController.listManagedDevices
);
router.post(
  '/devices/logout-all',
  authMiddleware,
  ownerOnlyMiddleware,
  authController.logoutAllManagedDevices
);
router.post(
  '/devices/:id/logout',
  authMiddleware,
  ownerOnlyMiddleware,
  authController.logoutManagedDevice
);
router.patch(
  '/devices/:id/block',
  authMiddleware,
  ownerOnlyMiddleware,
  deviceBlockValidation,
  authController.blockManagedDevice
);
router.patch(
  '/devices/:id/unblock',
  authMiddleware,
  ownerOnlyMiddleware,
  authController.unblockBlockedDevice
);
router.get(
  '/blocked-devices',
  authMiddleware,
  adminOrOwnerMiddleware,
  authController.listBlockedDevices
);
router.patch(
  '/blocked-devices/:id/unblock',
  authMiddleware,
  adminOrOwnerMiddleware,
  authController.unblockBlockedDevice
);

module.exports = router;
