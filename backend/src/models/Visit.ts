import mongoose, { Schema, type InferSchemaType } from 'mongoose';

const PhotoSchema = new Schema(
  {
    url: { type: String, required: true },
    thumbnailUrl: { type: String, default: null },
    createdAt: { type: Date, required: true },
  },
  { _id: false },
);

const ReactionSchema = new Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    emoji: { type: String, required: true, trim: true },
  },
  { _id: false },
);

const VisitSchema = new Schema(
  {
    companyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Company',
      required: true,
    },
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    createdByUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    workerName: { type: String, required: true, trim: true },
    note: { type: String, default: '' },
    serviceType: { type: String, required: true, trim: true },
    serviceChecklist: { type: [String], default: [] },
    photos: { type: [PhotoSchema], default: [] },
    reactions: { type: [ReactionSchema], default: [] },
    createdAt: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true },
);

export type Visit = InferSchemaType<typeof VisitSchema>;

export default mongoose.model('Visit', VisitSchema);
