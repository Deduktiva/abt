require 'test_helper'

class UserEmailTest < ActiveSupport::TestCase
  test 'normalizes address before save' do
    email = users(:alice).emails.create!(address: '  NEW@Example.Com  ')
    assert_equal 'new@example.com', email.address
  end

  test 'requires valid email format' do
    email = users(:alice).emails.build(address: 'not-an-email')
    assert_not email.valid?
  end

  test 'rejects duplicate addresses' do
    dup = users(:bob).emails.build(address: 'alice@example.com')
    assert_not dup.valid?
  end

  test 'generate_confirmation_token! stores digest only' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    plaintext = email.generate_confirmation_token!
    assert plaintext.length > 20
    email.reload
    assert email.confirmation_token_digest.present?
    assert_not_equal plaintext, email.confirmation_token_digest
    assert email.confirmation_expires_at > Time.current
  end

  test 'find_by_confirmation_token returns email for matching plaintext' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    plaintext = email.generate_confirmation_token!
    found = UserEmail.find_by_confirmation_token(plaintext)
    assert_equal email, found
  end

  test 'find_by_confirmation_token rejects expired tokens' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    plaintext = email.generate_confirmation_token!
    email.update_column(:confirmation_expires_at, 1.minute.ago)
    assert_nil UserEmail.find_by_confirmation_token(plaintext)
  end

  test 'find_by_confirmation_token rejects already-confirmed email' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    plaintext = email.generate_confirmation_token!
    email.confirm!
    assert_nil UserEmail.find_by_confirmation_token(plaintext)
  end

  test 'confirm! sets confirmed_at and clears token' do
    email = users(:alice).emails.create!(address: 'new@example.com')
    email.generate_confirmation_token!
    email.confirm!
    assert email.confirmed?
    assert_nil email.confirmation_token_digest
    assert_nil email.confirmation_expires_at
  end
end
