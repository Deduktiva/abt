class UserMailer < ApplicationMailer
  def email_confirmation(user_email, confirmation_url)
    @user = user_email.user
    @email = user_email
    @confirmation_url = confirmation_url
    @expires_at = user_email.confirmation_expires_at
    mail(to: user_email.address, subject: 'Confirm your email address')
  end

  def email_added_notice(user, new_address, recipient)
    @user = user
    @new_address = new_address
    mail(to: recipient, subject: 'Email address added to your account')
  end

  def email_removed_notice(user, removed_address, recipient)
    @user = user
    @removed_address = removed_address
    mail(to: recipient, subject: 'Email address removed from your account')
  end

  def passkey_added_notice(user, credential, recipient)
    @user = user
    @credential = credential
    mail(to: recipient, subject: 'Passkey added to your account')
  end

  def passkey_removed_notice(user, credential_nickname, recipient)
    @user = user
    @credential_nickname = credential_nickname
    mail(to: recipient, subject: 'Passkey removed from your account')
  end

  def passkey_reset_invite(user, invite_url, recipient)
    @user = user
    @invite_url = invite_url
    mail(to: recipient, subject: 'Register a new passkey for your account')
  end
end
