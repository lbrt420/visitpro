import nodemailer from 'nodemailer';

type MailerConfig = {
  host: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  fromEmail: string;
  fromName: string;
  brandName: string;
  appUrl: string;
  appLogoUrl?: string;
};

export type SendClientInviteInput = {
  toEmail: string;
  clientName: string;
  propertyName: string;
  invitedByName: string;
  username: string;
  temporaryPassword?: string;
};

export type SendVisitReportInput = {
  toEmails: string[];
  propertyName: string;
  workerName: string;
  note: string;
  createdAtIso: string;
  serviceTypeLabel: string;
  checklistItems: string[];
  photoUrls: string[];
};

export type SendWorkerInviteInput = {
  toEmail: string;
  workerName: string;
  companyName: string;
  invitedByName: string;
  temporaryPassword?: string;
};

export class InviteMailer {
  constructor(private readonly config: MailerConfig) {}

  private createTransport() {
    return nodemailer.createTransport({
      host: this.config.host,
      port: this.config.port,
      secure: this.config.secure,
      auth: {
        user: this.config.user,
        pass: this.config.pass,
      },
    });
  }

  private renderBrandedHtml(params: {
    preheader: string;
    title: string;
    bodyHtml: string;
    ctaLabel?: string;
    ctaUrl?: string;
  }): string {
    const brandName = escapeHtml(this.config.brandName || this.config.fromName || 'visitpro');
    const appUrl = escapeHtml(this.config.appUrl);
    const hasLogo = Boolean(this.config.appLogoUrl);
    const logoHtml = hasLogo
      ? `<img src="${escapeHtml(this.config.appLogoUrl || '')}" alt="${brandName}" style="height:56px; max-width:200px; object-fit:contain;" />`
      : `<div style="font-size:24px; font-weight:800; color:#0f766e; letter-spacing:0.3px;">${brandName}</div>`;
    const appNameUnderLogo = hasLogo
      ? `<div style="margin-top:6px; font-size:14px; font-weight:700; color:#0f172a; letter-spacing:0.2px;">${brandName}</div>`
      : '';

    const ctaHtml = params.ctaLabel && params.ctaUrl
      ? `
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin-top:20px;">
          <tr>
            <td style="border-radius:10px; background:#0f766e;">
              <a href="${escapeHtml(params.ctaUrl)}" style="display:inline-block; padding:12px 18px; color:#ffffff; text-decoration:none; font-weight:700;">
                ${escapeHtml(params.ctaLabel)}
              </a>
            </td>
          </tr>
        </table>
      `
      : '';

    return `
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>${escapeHtml(params.title)}</title>
        </head>
        <body style="margin:0; padding:0; background:#f4f7f7; font-family:Arial,Helvetica,sans-serif; color:#0f172a;">
          <div style="display:none; max-height:0; overflow:hidden; opacity:0;">${escapeHtml(params.preheader)}</div>
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f4f7f7; padding:22px 12px;">
            <tr>
              <td align="center">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:640px;">
                  <tr>
                    <td align="center" style="padding:8px 0 14px;">
                      ${logoHtml}
                      ${appNameUnderLogo}
                    </td>
                  </tr>
                  <tr>
                    <td style="background:#ffffff; border:1px solid #e2e8f0; border-radius:14px; padding:22px;">
                      <h2 style="margin:0 0 12px; font-size:22px; line-height:1.3; color:#0f766e;">${escapeHtml(params.title)}</h2>
                      <div style="font-size:15px; line-height:1.7; color:#1f2937;">
                        ${params.bodyHtml}
                      </div>
                      ${ctaHtml}
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:14px 8px 0; text-align:center; color:#64748b; font-size:12px;">
                      ${brandName} • <a href="${appUrl}" style="color:#0f766e; text-decoration:none;">${appUrl}</a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </body>
      </html>
    `;
  }

  async sendClientInvite(input: SendClientInviteInput): Promise<void> {
    const transport = this.createTransport();

    const loginHint = input.temporaryPassword
      ? `Log in with your email: ${input.toEmail}\nTemporary password: ${input.temporaryPassword}`
      : `Log in with your email: ${input.toEmail}\nUse your existing password to sign in.`;

    const text = [
      `Hi ${input.clientName},`,
      '',
      `${input.invitedByName} invited you to view service updates for your property "${input.propertyName}".`,
      '',
      loginHint,
      '',
      `Open app: ${this.config.appUrl}`,
    ].join('\n');

    const html = this.renderBrandedHtml({
      preheader: `${input.invitedByName} invited you to view updates for your property ${input.propertyName}`,
      title: `You're invited to ${input.propertyName}`,
      bodyHtml: `
        <p style="margin:0 0 10px;">Hi ${escapeHtml(input.clientName)},</p>
        <p style="margin:0 0 10px;">
          <strong>${escapeHtml(input.invitedByName)}</strong> invited you to view service updates for your property
          <strong>${escapeHtml(input.propertyName)}</strong>.
        </p>
        <div style="margin:14px 0; padding:12px; border-radius:10px; background:#ecfeff; border:1px solid #99f6e4;">
          <p style="margin:0 0 6px;"><strong>Email:</strong> ${escapeHtml(input.toEmail)}</p>
          <p style="margin:0;">
            <strong>${input.temporaryPassword ? 'Temporary password' : 'Password'}:</strong>
            ${input.temporaryPassword ? escapeHtml(input.temporaryPassword) : 'Use your existing password'}
          </p>
        </div>
      `,
      ctaLabel: `Open ${this.config.brandName || this.config.fromName || 'visitpro'}`,
      ctaUrl: this.config.appUrl,
    });

    await transport.sendMail({
      from: `"${this.config.fromName}" <${this.config.fromEmail}>`,
      to: input.toEmail,
      subject: `You were invited to ${input.propertyName} on ${this.config.brandName || this.config.fromName || 'visitpro'}`,
      text,
      html,
    });
  }

  async sendVisitReport(input: SendVisitReportInput): Promise<void> {
    const recipients = Array.from(
      new Set(input.toEmails.map((value) => value.trim().toLowerCase()).filter(Boolean)),
    );
    if (recipients.length === 0) {
      return;
    }

    const transport = this.createTransport();

    const text = [
      `New visit report for "${input.propertyName}"`,
      '',
      `Worker: ${input.workerName}`,
      `Service: ${input.serviceTypeLabel}`,
      `Date: ${new Date(input.createdAtIso).toLocaleString()}`,
      '',
      `Note: ${input.note || '(No note provided)'}`,
      '',
      `Checklist: ${input.checklistItems.length > 0 ? input.checklistItems.join(', ') : '(No completed items)'}`,
      '',
      input.photoUrls.length > 0 ? 'Photos:' : 'No photos attached.',
      ...input.photoUrls,
      '',
      `Open app: ${this.config.appUrl}`,
    ].join('\n');

    const htmlChecklist = input.checklistItems.length > 0
      ? `<ul style="margin:8px 0 0 18px; padding:0;">${input.checklistItems.map((item) => `<li style="margin:0 0 4px;">${escapeHtml(item)}</li>`).join('')}</ul>`
      : '<p><em>No completed checklist items.</em></p>';

    const htmlPhotos = input.photoUrls.length > 0
      ? `
        <div>
          ${input.photoUrls
            .map(
              (url) => `
                <a href="${escapeHtml(url)}" target="_blank" rel="noreferrer">
                  <img src="${escapeHtml(url)}" alt="Visit photo" style="max-width: 100%; width: 220px; border-radius: 8px; margin: 6px 6px 0 0;" />
                </a>
              `,
            )
            .join('')}
        </div>
      `
      : '<p><em>No photos attached.</em></p>';

    const html = this.renderBrandedHtml({
      preheader: `New visit report for ${input.propertyName}`,
      title: `Visit update: ${input.propertyName}`,
      bodyHtml: `
        <p style="margin:0 0 10px;">
          <strong>Worker:</strong> ${escapeHtml(input.workerName)}<br />
          <strong>Service:</strong> ${escapeHtml(input.serviceTypeLabel)}<br />
          <strong>Date:</strong> ${escapeHtml(new Date(input.createdAtIso).toLocaleString())}
        </p>
        <p style="margin:0 0 10px;">
          <strong>Note:</strong> ${escapeHtml(input.note || '(No note provided)')}
        </p>
        <div style="margin:12px 0; padding:12px; border-radius:10px; background:#f8fafc; border:1px solid #e2e8f0;">
          <strong>Checklist</strong>
          ${htmlChecklist}
        </div>
        <div style="margin-top:12px;">
          <strong>Photos</strong>
          ${htmlPhotos}
        </div>
      `,
      ctaLabel: `Open ${this.config.brandName || this.config.fromName || 'visitpro'}`,
      ctaUrl: this.config.appUrl,
    });

    await transport.sendMail({
      from: `"${this.config.fromName}" <${this.config.fromEmail}>`,
      to: recipients.join(', '),
      subject: `Visit update: ${input.propertyName}`,
      text,
      html,
    });
  }

  async sendWorkerInvite(input: SendWorkerInviteInput): Promise<void> {
    const transport = this.createTransport();

    const loginHint = input.temporaryPassword
      ? `Log in with your email: ${input.toEmail}\nTemporary password: ${input.temporaryPassword}`
      : `Log in with your email: ${input.toEmail}\nUse your existing password to sign in.`;

    const text = [
      `Hi ${input.workerName},`,
      '',
      `${input.invitedByName} invited you to the ${input.companyName} team.`,
      '',
      loginHint,
      '',
      `Open app: ${this.config.appUrl}`,
    ].join('\n');

    const html = this.renderBrandedHtml({
      preheader: `${input.invitedByName} invited you to ${input.companyName}`,
      title: `You were invited to ${input.companyName}`,
      bodyHtml: `
        <p style="margin:0 0 10px;">Hi ${escapeHtml(input.workerName)},</p>
        <p style="margin:0 0 10px;">
          <strong>${escapeHtml(input.invitedByName)}</strong> invited you to join the
          <strong>${escapeHtml(input.companyName)}</strong> team.
        </p>
        <div style="margin:14px 0; padding:12px; border-radius:10px; background:#ecfeff; border:1px solid #99f6e4;">
          <p style="margin:0 0 6px;"><strong>Email:</strong> ${escapeHtml(input.toEmail)}</p>
          <p style="margin:0;">
            <strong>${input.temporaryPassword ? 'Temporary password' : 'Password'}:</strong>
            ${input.temporaryPassword ? escapeHtml(input.temporaryPassword) : 'Use your existing password'}
          </p>
        </div>
      `,
      ctaLabel: `Open ${this.config.brandName || this.config.fromName || 'visitpro'}`,
      ctaUrl: this.config.appUrl,
    });

    await transport.sendMail({
      from: `"${this.config.fromName}" <${this.config.fromEmail}>`,
      to: input.toEmail,
      subject: `Team invite: ${input.companyName}`,
      text,
      html,
    });
  }
}

export function createInviteMailer(config: MailerConfig): InviteMailer | null {
  if (!config.host || !config.user || !config.pass || !config.fromEmail) {
    return null;
  }
  return new InviteMailer(config);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
