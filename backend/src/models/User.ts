import mongoose, { Schema, type InferSchemaType } from 'mongoose';

const UserSchema = new Schema(
  {
    companyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Company',
      default: null,
    },
    role: {
      type: String,
      enum: ['owner', 'worker', 'client'],
      required: true,
    },
    companyAccessLevel: {
      type: String,
      enum: ['owner', 'admin', 'member'],
      default: 'member',
      trim: true,
    },
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    username: { type: String, unique: true, sparse: true, trim: true },
    avatarUrl: { type: String, default: null, trim: true },
    pushTokens: [{ type: String, trim: true }],
    passwordHash: { type: String, required: true },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

export type User = InferSchemaType<typeof UserSchema>;

export default mongoose.model('User', UserSchema);
