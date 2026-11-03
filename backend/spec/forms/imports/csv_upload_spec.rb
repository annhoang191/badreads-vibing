require "rails_helper"

RSpec.describe Imports::CsvUpload do
  def upload(path_or_content, name: "export.csv", type: "text/csv")
    io = path_or_content.is_a?(Pathname) ? path_or_content.open : StringIO.new(path_or_content)
    Rack::Test::UploadedFile.new(io, type, original_filename: name)
  end

  def form(file) = described_class.new(file:)

  it "accepts a Goodreads export" do
    form = form(upload(file_fixture("goodreads_export.csv")))

    expect(form.check!).to eq(form)
    expect(form.filename).to eq("export.csv")
  end

  it "accepts a BOM-prefixed header" do
    expect(form(upload("﻿Book Id,Title,Author,Exclusive Shelf\n")).check!).to be_a(described_class)
  end

  it "rejects a missing file" do
    expect { form(nil).check! }.to raise_error(ApiError::InvalidFile)
    expect { form("string").check! }.to raise_error(ApiError::InvalidFile)
  end

  it "rejects non-csv files" do
    expect { form(upload("a,b", name: "x.txt", type: "text/plain")).check! }.to raise_error(ApiError::InvalidFile)
  end

  it "accepts a csv content type with another extension" do
    expect(form(upload("Book Id,Title,Author,Exclusive Shelf\n", name: "x.dat")).check!).to be_a(described_class)
  end

  it "rejects files over 10 MB" do
    file = upload("Book Id,Title,Author,Exclusive Shelf\n")
    allow(file).to receive(:size).and_return(11.megabytes)

    expect { form(file).check! }.to raise_error(ApiError::InvalidFile, /10 MB/)
  end

  it "rejects a CSV that is not a Goodreads export, naming missing headers" do
    expect { form(upload(file_fixture("not_goodreads.csv"))).check! }
      .to raise_error(ApiError::InvalidGoodreadsExport, /missing Book Id, Title, Author, Exclusive Shelf/)
  end

  it "rejects malformed CSV as not a Goodreads export instead of erroring" do
    expect { form(upload("Book Id,\"Title\n")).check! }
      .to raise_error(ApiError::InvalidGoodreadsExport)
  end

  it "leaves the file rewound for attaching" do
    file = upload(file_fixture("goodreads_export.csv"))
    form(file).check!

    expect(file.read(7)).to eq("Book Id")
  end
end
