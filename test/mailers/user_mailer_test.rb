require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  setup do
    IssuerCompany.find_or_create_by!(active: true) do |c|
      c.short_name = 'Test'
      c.legal_name = 'Test GmbH'
      c.document_email_from = 'noreply@example.com'
      c.address = "Line 1\nLine 2"
      c.currency = 'EUR'
    end
  end

  def body_text(mail)
    mail.parts.map { |p| p.body.to_s }.join("\n")
  end

  test 'email_confirmation includes confirmation URL' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    email.generate_confirmation_token!
    url = 'http://example.com/account/email_confirmations/sometoken'

    mail = UserMailer.email_confirmation(email, url)
    assert_equal [ 'new@example.com' ], mail.to
    assert_match url, body_text(mail)
  end

  test 'email_added_notice goes to the recipient with new address in body' do
    mail = UserMailer.email_added_notice(users(:alice), 'newish@example.com', 'alice@example.com')
    assert_equal [ 'alice@example.com' ], mail.to
    assert_match 'newish@example.com', body_text(mail)
  end

  test 'email_removed_notice mentions removed address' do
    mail = UserMailer.email_removed_notice(users(:alice), 'old@example.com', 'alice@example.com')
    assert_match 'old@example.com', body_text(mail)
  end

  test 'passkey_added_notice mentions credential nickname' do
    cred = users(:alice).credentials.first
    mail = UserMailer.passkey_added_notice(users(:alice), cred, 'alice@example.com')
    assert_match cred.nickname, body_text(mail)
  end

  test 'passkey_removed_notice mentions the removed nickname' do
    mail = UserMailer.passkey_removed_notice(users(:alice), 'Old key', 'alice@example.com')
    assert_match 'Old key', body_text(mail)
  end

  test 'passkey_reset_invite includes the invite URL' do
    url = 'http://example.com/invites/abc123'
    mail = UserMailer.passkey_reset_invite(users(:alice), url, 'alice@example.com')
    assert_match url, body_text(mail)
  end
end
