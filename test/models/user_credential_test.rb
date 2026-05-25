require "test_helper"

class UserCredentialTest < ActiveSupport::TestCase
  def build_credential(**overrides)
    users(:alice).credentials.build({
      external_id: "new-ext-id",
      public_key: "new-pubkey",
      nickname: "New Key",
      sign_count: 0
    }.merge(overrides))
  end

  test "requires external_id" do
    cred = build_credential(external_id: nil)
    assert_not cred.valid?
    assert_includes cred.errors[:external_id], "can't be blank"
  end

  test "external_id must be unique" do
    cred = build_credential(external_id: user_credentials(:alice_key).external_id)
    assert_not cred.valid?
    assert_includes cred.errors[:external_id], "has already been taken"
  end

  test "requires public_key" do
    cred = build_credential(public_key: nil)
    assert_not cred.valid?
    assert_includes cred.errors[:public_key], "can't be blank"
  end

  test "requires nickname" do
    cred = build_credential(nickname: nil)
    assert_not cred.valid?
    assert_includes cred.errors[:nickname], "can't be blank"
  end

  test "nickname is limited to 80 characters" do
    cred = build_credential(nickname: "x" * 81)
    assert_not cred.valid?
    assert_includes cred.errors[:nickname], "is too long (maximum is 80 characters)"
  end

  test "sign_count must be a non-negative integer" do
    cred = build_credential(sign_count: -1)
    assert_not cred.valid?
    assert_includes cred.errors[:sign_count], "must be greater than or equal to 0"

    cred = build_credential(sign_count: 1.5)
    assert_not cred.valid?
    assert_includes cred.errors[:sign_count], "must be an integer"
  end

  test "touch_used! updates sign_count and last_used_at" do
    cred = user_credentials(:alice_key)
    cred.update_column(:last_used_at, 1.day.ago)
    cred.touch_used!(42)
    cred.reload
    assert_equal 42, cred.sign_count
    assert_in_delta Time.current.to_f, cred.last_used_at.to_f, 5
  end
end
