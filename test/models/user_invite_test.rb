require 'test_helper'

class UserInviteTest < ActiveSupport::TestCase
  test 'create_signup! returns plaintext and stores digest' do
    invite, plaintext = UserInvite.create_signup!(actor: users(:alice))
    assert plaintext.length > 20
    assert_equal Digest::SHA256.hexdigest(plaintext), invite.token_digest
    assert_equal UserInvite::PURPOSE_SIGNUP, invite.purpose
    assert_in_delta UserInvite::EXPIRY.from_now.to_f, invite.expires_at.to_f, 5
  end

  test 'create_passkey_reset! requires target_user' do
    assert_raises(ActiveRecord::RecordInvalid) do
      UserInvite.create!(
        token_digest: 'abc',
        purpose: UserInvite::PURPOSE_PASSKEY_RESET,
        expires_at: 1.hour.from_now
      )
    end
  end

  test 'find_usable matches valid plaintext token' do
    invite, plaintext = UserInvite.create_signup!(actor: nil)
    assert_equal invite, UserInvite.find_usable(plaintext)
  end

  test 'find_usable rejects expired tokens' do
    invite, plaintext = UserInvite.create_signup!(actor: nil)
    invite.update_column(:expires_at, 1.minute.ago)
    assert_nil UserInvite.find_usable(plaintext)
  end

  test 'find_usable rejects used tokens' do
    invite, plaintext = UserInvite.create_signup!(actor: nil)
    invite.update!(used_at: Time.current, used_by_user: users(:alice))
    assert_nil UserInvite.find_usable(plaintext)
  end

  test 'consume! marks invite used and tracks user' do
    invite, _plain = UserInvite.create_signup!(actor: nil)
    invite.consume!(user: users(:alice))
    assert invite.used_at.present?
    assert_equal users(:alice), invite.used_by_user
    assert_not invite.usable?
  end

  test 'signup invite cannot have a target_user' do
    invite = UserInvite.new(
      token_digest: 'xyz',
      purpose: UserInvite::PURPOSE_SIGNUP,
      target_user: users(:alice),
      expires_at: 1.hour.from_now
    )
    assert_not invite.valid?
  end
end
