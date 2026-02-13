import mongoose, { Schema, type InferSchemaType } from 'mongoose';

const CompanySchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    address: { type: String, default: '', trim: true },
    orgNumber: { type: String, default: '', trim: true },
    taxId: { type: String, default: '', trim: true },
    servicesOffered: { type: [String], default: [] },
    logoUrl: { type: String, default: '', trim: true },
    billingPlan: { type: String, default: '', trim: true },
    billingCycle: { type: String, default: 'yearly', trim: true },
    billingClientRange: { type: String, default: '', trim: true },
    subscriptionStatus: { type: String, default: 'inactive', trim: true },
    trialEndsAt: { type: Date, default: null },
    stripeCustomerId: { type: String, default: '', trim: true },
    stripeSubscriptionId: { type: String, default: '', trim: true },
  },
  { timestamps: true },
);

export type Company = InferSchemaType<typeof CompanySchema>;

export default mongoose.model('Company', CompanySchema);
