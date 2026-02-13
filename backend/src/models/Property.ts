import mongoose, { Schema, type InferSchemaType } from 'mongoose';

const PropertySchema = new Schema(
  {
    companyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Company',
      required: true,
    },
    name: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    clientShareToken: { type: String, required: true, unique: true, index: true },
    workerIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    clientIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  },
  { timestamps: true },
);

export type Property = InferSchemaType<typeof PropertySchema>;

export default mongoose.model('Property', PropertySchema);
