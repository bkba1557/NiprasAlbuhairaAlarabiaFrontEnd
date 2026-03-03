const mongoose = require('mongoose');

const QualificationStationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    city: { type: String, required: true, trim: true },
    region: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    status: {
      type: String,
      enum: ['qualified', 'unqualified'],
      default: 'unqualified',
    },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
    notes: { type: String, default: '' },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true, toJSON: { virtuals: true }, toObject: { virtuals: true } }
);

module.exports = mongoose.model(
  'QualificationStation',
  QualificationStationSchema
);
