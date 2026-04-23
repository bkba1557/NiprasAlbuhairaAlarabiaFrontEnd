

const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const cron = require('node-cron');
const moment = require('moment');
const { initFirebase } = require('./config/firebase');

// Load environment variables (always from backend/.env)
dotenv.config({ path: path.join(__dirname, '.env') });

// Initialize Firebase Admin early to validate credentials
initFirebase();

// Tenancy (multi-company) support: apply plugin before loading models.
mongoose.plugin(require('./utils/tenantPlugin'));
const { bootstrapTenancy } = require('./services/tenancyBootstrapService');

const Maintenance = require('./models/Maintenance');
const Task = require('./models/Task');
const NotificationService = require('./services/notificationService');
const RealtimeService = require('./services/realtime.service');
const orderController = require('./controllers/orderController');
const ownerOrderNotificationService = require('./services/ownerOrderNotificationService');
const { startBackupJob } = require('./jobs/backupJob');
const { startDriverDocumentExpiryJob } = require('./jobs/driverDocumentExpiryJob');
const { startVehicleDocumentExpiryJob } = require('./jobs/vehicleDocumentExpiryJob');
const { startTankerAramcoStickerExpiryJob } = require('./jobs/tankerAramcoStickerExpiryJob');
const { startStatementExpiryJob } = require('./jobs/statementExpiryJob');


const authRoutes = require('./routes/authRoutes');
const orderRoutes = require('./routes/orderRoutes');
const activityRoutes = require('./routes/activityRoutes');
const customerRoutes = require('./routes/customerRoutes'); 
const notificationRoutes = require('./routes/notificationRoutes');
const driverRoutes = require('./routes/driverRoutes');
const supplierRoutes = require('./routes/supplierRoutes');
const reportRoutes = require('./routes/reportRoutes');
const deviceRoutes = require('./routes/deviceRoutes');
const maintenanceRoutes = require('./routes/maintenanceRoutes');
const userRoutes = require('./routes/userRoutes');
const fuelStationRoutes = require('./routes/fuelStationRoutes');
const maintenanceRecordRoutes = require('./routes/maintenanceRecordRoutes');
const technicianReportRoutes = require('./routes/technicianReportRoutes');
const alertRoutes = require('./routes/alertRoutes');
const approvalRequestRoutes = require('./routes/approvalRequestRoutes');
const technicianLocationRoutes = require('./routes/technicianLocationRoutes');
const stationRoutes = require('./routes/stationRoutes');
const workshopFuelRoutes = require('./routes/workshopFuelRoutes');
const custodyDocumentRoutes = require('./routes/custodyDocumentRoutes');
const marketingStationRoutes = require('./routes/marketingStationRoutes');
const stationInspectionRoutes = require('./routes/stationInspectionRoutes');
const qualificationStationRoutes = require('./routes/qualificationStationRoutes');
const stationMaintenanceRoutes = require('./routes/stationMaintenanceRoutes');
const noteRoutes = require('./routes/noteRoutes');
const taskRoutes = require('./routes/taskRoutes');
const chatRoutes = require('./routes/chatRoutes');
const mapsRoutes = require('./routes/mapsRoutes');
const tankerRoutes = require('./routes/tankerRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const driverLocationRoutes = require('./routes/driverLocationRoutes');
const trackingRoutes = require('./routes/trackingRoutes');
const contractRoutes = require('./routes/contractRoutes');
const archiveDocumentRoutes = require('./routes/archiveDocumentRoutes');
const inventoryRoutes = require('./routes/inventoryRoutes');
const aiAssistantRoutes = require('./routes/aiAssistantRoutes');
const whatsappRoutes = require('./routes/whatsappRoutes');
const backupRoutes = require('./routes/backupRoutes');
const circularRoutes = require('./routes/circularRoutes');
const dailyReportRoutes = require('./routes/dailyReportRoutes');
const templateRoutes = require('./routes/templateRoutes');
const systemPauseRoutes = require('./routes/systemPauseRoutes');
const statementRoutes = require('./routes/statementRoutes');
const { sendDueNotes } = require('./services/noteReminderService');


const EmployeeRoutes = require('./routes/employeeRoutes');
const AttendanceRoutes = require('./routes/attendanceRoutes');
const SalaryRoutes = require('./routes/salaryRoutes');
const AdvanceRoutes = require('./routes/advanceRoutes');
const PenaltyRoutes = require('./routes/penaltyRoutes');
const LocationRoutes = require('./routes/locationRoutes');
const DashboardRoutes = require('./routes/dashboardRoutes');

// ===============================
// APP INIT
// ===============================
const app = express();

// Middleware
app.use((req, res, next) => {
  // Chrome Private Network Access preflight (when a secure origin calls a private IP)
  if (req.headers['access-control-request-private-network'] === 'true') {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
});

const corsOptions = {
  origin: true,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['Content-Disposition'],
  maxAge: 86400,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/api/uploads', express.static(path.join(__dirname, 'uploads')));

// ===============================
// DATABASE
// ===============================
const MONGODB_URL =
  process.env.MONGODB_URL ||
  'mongodb+srv://nasser67:Qwert1557@niprasalbuhaira.ez3ump.mongodb.net/';

const MONGODB_OPTIONS = {
  useNewUrlParser: true,
  useUnifiedTopology: true,
};


app.use('/api/auth', authRoutes);
app.use('/api/backup', backupRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/activities', activityRoutes);
app.use('/api/customers', customerRoutes); 
app.use('/api/notifications', notificationRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/suppliers', supplierRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/maintenance', maintenanceRoutes);
app.use('/api/users', userRoutes);
app.use('/api/fuel-stations', fuelStationRoutes);
app.use('/api/maintenance-records', maintenanceRecordRoutes);
app.use('/api/notes', noteRoutes);
app.use('/api/technician-reports', technicianReportRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/approval-requests', approvalRequestRoutes);
app.use('/api/technician-locations', technicianLocationRoutes);
app.use('/api/stations', stationRoutes);
app.use('/api/workshop-fuel', workshopFuelRoutes);
app.use('/api/custody-documents', custodyDocumentRoutes);
app.use('/api/station-marketing', marketingStationRoutes);
app.use('/api/station-inspections', stationInspectionRoutes);
app.use('/api/qualification-stations', qualificationStationRoutes);
app.use('/api/station-maintenance', stationMaintenanceRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/maps', mapsRoutes);
app.use('/api/tankers', tankerRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/driver-locations', driverLocationRoutes);
app.use('/api/tracking', trackingRoutes);
app.use('/api/contracts', contractRoutes);
app.use('/api/archive-documents', archiveDocumentRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/ai-assistant', aiAssistantRoutes);
app.use('/api/whatsapp', whatsappRoutes);
app.use('/api/circulars', circularRoutes);
app.use('/api/daily-reports', dailyReportRoutes);
app.use('/api/templates', templateRoutes);
app.use('/api/system-pause', systemPauseRoutes);
app.use('/api/statements', statementRoutes);


app.use('/api/employees', EmployeeRoutes);
app.use('/api/attendance', AttendanceRoutes);
app.use('/api/salaries', SalaryRoutes);
app.use('/api/advances', AdvanceRoutes);
app.use('/api/penalties', PenaltyRoutes);
app.use('/api/locations', LocationRoutes);
app.use('/api/dashboard', DashboardRoutes);

// ===============================
// BACKUP JOB (Daily at 12:00)
// ===============================
// Started after DB connect

// ===============================
// 🕒 MONTHLY MAINTENANCE CRON
// ===============================
cron.schedule('5 0 1 * *', async () => {
  console.log('🕒 Running monthly maintenance creation job...');

  try {
    const newMonth = moment().format('YYYY-MM');
    const prevMonth = moment().subtract(1, 'month').format('YYYY-MM');

    const lastRecords = await Maintenance.aggregate([
      { $match: { inspectionMonth: prevMonth } },
      {
        $sort: { createdAt: -1 }
      },
      {
        $group: {
          _id: '$plateNumber',
          record: { $first: '$$ROOT' }
        }
      }
    ]);

    for (const item of lastRecords) {
      const old = item.record;

      const exists = await Maintenance.findOne({
        plateNumber: old.plateNumber,
        inspectionMonth: newMonth
      });

      if (exists) continue;

      const daysInMonth = moment(newMonth, 'YYYY-MM').daysInMonth();
      const dailyChecks = [];

      for (let d = 1; d <= daysInMonth; d++) {
        dailyChecks.push({
          date: moment(`${newMonth}-${d}`, 'YYYY-MM-DD').toDate(),
          status: 'pending'
        });
      }

      await Maintenance.create({
        // ===== COPY STATIC DATA =====
        driverId: old.driverId,
        driverName: old.driverName,
        tankNumber: old.tankNumber,
        plateNumber: old.plateNumber,
        driverLicenseNumber: old.driverLicenseNumber,
        driverLicenseExpiry: old.driverLicenseExpiry,
        vehicleLicenseNumber: old.vehicleLicenseNumber,
        vehicleLicenseExpiry: old.vehicleLicenseExpiry,
        vehicleType: old.vehicleType,
        fuelType: old.fuelType,

        vehicleOperatingCardNumber: old.vehicleOperatingCardNumber,
        vehicleOperatingCardIssueDate: old.vehicleOperatingCardIssueDate,
        vehicleOperatingCardExpiryDate: old.vehicleOperatingCardExpiryDate,
        vehicleOperatingCardAttachments: old.vehicleOperatingCardAttachments,

        driverOperatingCardName: old.driverOperatingCardName,
        driverOperatingCardNumber: old.driverOperatingCardNumber,
        driverOperatingCardIssueDate: old.driverOperatingCardIssueDate,
        driverOperatingCardExpiryDate: old.driverOperatingCardExpiryDate,
        driverOperatingCardAttachments: old.driverOperatingCardAttachments,

        vehicleRegistrationSerialNumber: old.vehicleRegistrationSerialNumber,
        vehicleRegistrationNumber: old.vehicleRegistrationNumber,
        vehicleRegistrationIssueDate: old.vehicleRegistrationIssueDate,
        vehicleRegistrationExpiryDate: old.vehicleRegistrationExpiryDate,

        driverInsurancePolicyNumber: old.driverInsurancePolicyNumber,
        driverInsuranceIssueDate: old.driverInsuranceIssueDate,
        driverInsuranceExpiryDate: old.driverInsuranceExpiryDate,

        vehicleInsurancePolicyNumber: old.vehicleInsurancePolicyNumber,
        vehicleInsuranceIssueDate: old.vehicleInsuranceIssueDate,
        vehicleInsuranceExpiryDate: old.vehicleInsuranceExpiryDate,

        vehiclePeriodicInspectionIssueDate: old.vehiclePeriodicInspectionIssueDate,
        vehiclePeriodicInspectionExpiryDate: old.vehiclePeriodicInspectionExpiryDate,

        insuranceNumber: old.insuranceNumber,
        insuranceExpiry: old.insuranceExpiry,

        // ===== MONTH DATA =====
        inspectionMonth: newMonth,
        inspectedBy: old.inspectedBy,
        inspectedByName: old.inspectedByName,

        dailyChecks,
        totalDays: daysInMonth,
        completedDays: 0,
        pendingDays: daysInMonth,
        monthlyStatus: 'غير مكتمل',

        // ===== RESET STATES =====
        lastOdometerReading: old.lastOdometerReading,
        lastOilChangeOdometer: old.lastOilChangeOdometer,
        totalDistanceSinceOilChange: old.totalDistanceSinceOilChange,

        status: 'active'
      });
    }

    console.log(`✅ Monthly maintenance created for ${newMonth}`);
  } catch (error) {
    console.error('❌ Monthly maintenance cron failed:', error.message);
  }
});




cron.schedule('*/15 * * * *', async () => {
  console.log('⏱️ Running merged order auto-execution job...');

  try {
    await orderController.autoExecuteMergedOrders();
  } catch (error) {
    console.error('❌ Merged order auto-execution job failed:', error);
  }
});

cron.schedule('0 9 * * 0', async () => {
  console.log('📊 Running weekly owner completed-orders summary job...');

  try {
    await ownerOrderNotificationService.sendWeeklyCompletedOrdersSummaryToOwner();
  } catch (error) {
    console.error('❌ Weekly owner summary job failed:', error);
  }
});

cron.schedule('55 23 28-31 * *', async () => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);

  // Run only on the actual last day of month.
  if (tomorrow.getDate() !== 1) {
    return;
  }

  console.log('📈 Running monthly owner completed-orders report job...');

  try {
    await ownerOrderNotificationService.sendMonthlyCompletedOrdersSummaryToOwner(now);
  } catch (error) {
    console.error('❌ Monthly owner report job failed:', error);
  }
});



cron.schedule('0 9 * * *', async () => {
  console.log('Running weekly-inactive customer alerts job...');

  try {
    await orderController.checkInactiveCustomersWeekly();
  } catch (error) {
    console.error('Inactive customer alerts job failed:', error);
  }
});

cron.schedule('0 23 * * *', async () => {
  console.log('🕒 Creating daily attendance records...');
  try {
    const Employee = require('./models/Employee');
    const Attendance = require('./models/Attendance');
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const employees = await Employee.find({ 
      status: 'نشط',
      'fingerprintEnrolled': true 
    });
    
    for (const employee of employees) {
      const existingRecord = await Attendance.findOne({
        employeeId: employee._id,
        date: today
      });
      
      if (!existingRecord) {
        const attendance = new Attendance({
          employeeId: employee._id,
          date: today,
          status: 'غياب' 
        });
        
        await attendance.save();
      }
    }
    
    console.log(`✅ Created attendance records for ${employees.length} employees`);
  } catch (error) {
    console.error('❌ Daily attendance cron failed:', error.message);
  }
});

cron.schedule('0 0 1 * *', async () => {
  console.log('🕒 Updating overdue advances...');
  try {
    const Advance = require('./models/Advance');
    
    const today = new Date();
    const overdueAdvances = await Advance.find({
      status: 'قسط',
      'repayments.status': 'مستحق',
      'repayments.dueDate': { $lt: today }
    });
    
    for (const advance of overdueAdvances) {
      advance.repayments.forEach(repayment => {
        if (repayment.status === 'مستحق' && repayment.dueDate < today) {
          repayment.status = 'متأخر';
        }
      });
      
      advance.status = 'متأخر';
      await advance.save();
    }
    
    console.log(`✅ Updated ${overdueAdvances.length} overdue advances`);
  } catch (error) {
    console.error('❌ Overdue advances cron failed:', error.message);
  }
});

cron.schedule('0 8 * * *', async () => {
  console.log('🕒 Checking contract and residency expiries...');
  try {
    const Employee = require('./models/Employee');
    // const Alert = require('./models/hr/Alert.model');
    
    const today = new Date();
    const nextMonth = new Date();
    nextMonth.setMonth(today.getMonth() + 1);
    
    const expiringContracts = await Employee.find({
      status: 'نشط',
      contractEndDate: { 
        $gte: today,
        $lte: nextMonth 
      }
    });
    
    // الموظفين الذين تنتهي إقاماتهم خلال الشهر القادم
    const expiringResidencies = await Employee.find({
      status: 'نشط',
      residencyExpiryDate: { 
        $gte: today,
        $lte: nextMonth 
      }
    });
    
    // إنشاء تنبيهات
    for (const employee of expiringContracts) {
      const daysLeft = Math.ceil((employee.contractEndDate - today) / (1000 * 60 * 60 * 24));
      
      const existingAlert = await Alert.findOne({
        employeeId: employee._id,
        type: 'contract_expiry',
        'metadata.daysLeft': daysLeft
      });
      
      if (!existingAlert) {
        const alert = new Alert({
          employeeId: employee._id,
          type: 'contract_expiry',
          title: `انتهاء عقد الموظف ${employee.name}`,
          message: `ينتهي عقد الموظف ${employee.name} بعد ${daysLeft} يوم`,
          priority: daysLeft <= 7 ? 'high' : daysLeft <= 30 ? 'medium' : 'low',
          metadata: {
            employeeName: employee.name,
            contractEndDate: employee.contractEndDate,
            daysLeft: daysLeft
          },
          status: 'unread'
        });
        
        await alert.save();
      }
    }
    
    for (const employee of expiringResidencies) {
      const daysLeft = Math.ceil((employee.residencyExpiryDate - today) / (1000 * 60 * 60 * 24));
      
      const existingAlert = await Alert.findOne({
        employeeId: employee._id,
        type: 'residency_expiry',
        'metadata.daysLeft': daysLeft
      });
      
      if (!existingAlert) {
        const alert = new Alert({
          employeeId: employee._id,
          type: 'residency_expiry',
          title: `انتهاء إقامة الموظف ${employee.name}`,
          message: `تنتهي إقامة الموظف ${employee.name} بعد ${daysLeft} يوم`,
          priority: daysLeft <= 7 ? 'high' : daysLeft <= 30 ? 'medium' : 'low',
          metadata: {
            employeeName: employee.name,
            residencyExpiryDate: employee.residencyExpiryDate,
            daysLeft: daysLeft
          },
          status: 'unread'
        });
        
        await alert.save();
      }
    }
    
    console.log(`✅ Created alerts for ${expiringContracts.length} contracts and ${expiringResidencies.length} residencies`);
  } catch (error) {
    console.error('❌ Expiry alerts cron failed:', error.message);
  }
});


cron.schedule('0 * * * *', async () => {
  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    const pendingTasks = await Task.find({
      status: 'assigned',
      $or: [
        { lastReminderAt: { $exists: false } },
        { lastReminderAt: { $lte: oneHourAgo } },
      ],
    }).limit(200);

    for (const task of pendingTasks) {
      await NotificationService.send({
        type: 'task_reminder',
        title: `تذكير بمهمة رقم ${task.taskCode}`,
        message: 'لديك مهمة لم يتم استلامها بعد.',
        data: { taskId: task._id.toString(), taskCode: task.taskCode },
        recipients: [task.assignedTo],
        createdBy: task.createdBy,
        channels: ['in_app', 'push', 'email'],
      });

      task.lastReminderAt = now;
      task.reminderCount = (task.reminderCount || 0) + 1;
      await task.save();
    }

    const overdueTasks = await Task.find({
      dueDate: { $lt: now },
      status: { $in: ['assigned', 'accepted', 'in_progress', 'rejected'] },
    }).limit(200);

    for (const task of overdueTasks) {
      task.status = 'overdue';
      await task.save();

      await NotificationService.send({
        type: 'task_overdue',
        title: `مهمة متأخرة رقم ${task.taskCode}`,
        message: 'تم رصد مهمة متأخرة عن الموعد المحدد.',
        data: { taskId: task._id.toString(), taskCode: task.taskCode },
        recipients: [task.assignedTo, task.createdBy],
        createdBy: task.createdBy,
        channels: ['in_app', 'push', 'email'],
      });
    }
  } catch (error) {
    console.error('TASK REMINDER JOB ERROR:', error.message);
  }
});

cron.schedule('* * * * *', async () => {
  try {
    await orderController.processDriverAssignmentReminders();
  } catch (error) {
    console.error('DRIVER ASSIGNMENT REMINDER JOB ERROR:', error.message);
  }
});

cron.schedule('*/15 * * * * *', async () => {
  try {
    const now = new Date();
    const overdueTasks = await Task.find({
      dueDate: { $lte: now },
      status: { $in: ['assigned', 'accepted', 'in_progress', 'rejected'] },
    }).limit(200);

    for (const task of overdueTasks) {
      const recipients = new Set();
      if (task.assignedTo) recipients.add(task.assignedTo.toString());
      if (task.createdBy) recipients.add(task.createdBy.toString());
      if (task.assignedBy) recipients.add(task.assignedBy.toString());
      if (Array.isArray(task.participants)) {
        task.participants.forEach((participant) => {
          if (participant?.user) {
            recipients.add(participant.user.toString());
          }
        });
      }

      task.statusBeforeOverdue = task.status;
      task.status = 'overdue';
      task.overdueNotifiedAt = now;
      await task.save();

      await NotificationService.send({
        type: 'task_overdue',
        title: `مهمة متأخرة رقم ${task.taskCode}`,
        message: 'تم رصد مهمة متأخرة عن الموعد المحدد.',
        data: {
          taskId: task._id.toString(),
          taskCode: task.taskCode,
          dueDate: task.dueDate,
          overduePenaltyAmount: Number(task.overduePenalty?.amount) || 0,
          overduePenaltyCurrency: task.overduePenalty?.currency || 'SAR',
        },
        recipients: Array.from(recipients),
        createdBy: task.createdBy,
        channels: ['in_app', 'push', 'email'],
      });
    }
  } catch (error) {
    console.error('TASK OVERDUE JOB ERROR:', error.message);
  }
});


app.get('/', (req, res) => {
  res.json({ 
    message: 'Fuel Supply Tracking System API',
    version: '2.0.0',
    modules: {
      tracking: 'نظام تتبع الوقود',
      hr: 'نظام شؤون الموظفين',
      maintenance: 'نظام الصيانة'
    },
    endpoints: {
      tracking: '/api',
      hr: '/api/hr',
      docs: 'Coming soon...'
    }
  });
});



// ===============================
// HEALTH CHECK
// ===============================
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// ===============================
// ERROR HANDLER
// ===============================
app.use((err, req, res, next) => {
  console.error('❌ Error:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Something went wrong!',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// ===============================
// 404 HANDLER
// ===============================
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.url} not found`
  });
});

// ===============================
// START SERVER
// ===============================
const PORT = process.env.PORT || 6030;
const server = http.createServer(app);
RealtimeService.init(server);
const start = async () => {
  try {
    await mongoose.connect(MONGODB_URL, MONGODB_OPTIONS);
    console.log('✅ MongoDB Connected Successfully');

    const defaultCompany = await bootstrapTenancy({ mongoose });
    if (defaultCompany?._id) {
      process.env.DEFAULT_COMPANY_ID = defaultCompany._id.toString();
    }
    console.log('✅ Tenancy bootstrap completed');

    // ===============================
    // BACKUP JOB (Daily at 12:00)
    // ===============================
    startBackupJob();
    startDriverDocumentExpiryJob();
    startVehicleDocumentExpiryJob();
    startTankerAramcoStickerExpiryJob();
    startStatementExpiryJob();

    server.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`🌐 HR System available at http://localhost:${PORT}/api/hr`);
      console.log(`📊 Tracking System available at http://localhost:${PORT}/api`);
      console.log(`🔌 WebSocket signaling available at ws://localhost:${PORT}/ws`);
    });
  } catch (err) {
    console.error('❌ Startup error:', err);
    process.exit(1);
  }
};

start();


