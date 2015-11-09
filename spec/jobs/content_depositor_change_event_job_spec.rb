require 'spec_helper'

describe ContentDepositorChangeEventJob do
  let!(:depositor) { FactoryGirl.find_or_create(:jill) }
  let!(:receiver) { FactoryGirl.find_or_create(:archivist) }
  let!(:file) do
    FileSet.new do |f|
      f.apply_depositor_metadata(depositor.user_key)
      f.save!
    end
  end
  let!(:work) do
    GenericWork.new do |w|
      w.apply_depositor_metadata(depositor.user_key)
      w.title = ["demoname"]
      w.save!
    end
  end

  before do
    work.file_sets += [file]
    described_class.new(work.id, receiver.user_key).run
  end

  it "changes the depositor and records an original depositor" do
    work.reload
    expect(work.depositor).to eq receiver.user_key
    expect(work.proxy_depositor).to eq depositor.user_key
    expect(work.edit_users).to include(receiver.user_key, depositor.user_key)
  end

  it "changes the depositor of the child file sets" do
    file.reload
    expect(file.depositor).to eq receiver.user_key
    expect(file.edit_users).to include(receiver.user_key, depositor.user_key)
  end
end
