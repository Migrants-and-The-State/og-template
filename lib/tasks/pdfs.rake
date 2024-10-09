require 'csv'
require 'pdf-reader'
require 'vips'

def records
  @records ||= CSV.open(AFILES_CSV_FILE, headers: :first_row).map(&:to_h)
end

def records=(records)
  @records = records
end

def records_hash 
  @records_hash ||= pickle(records)
end

def records_hash=(records_hash)
  @records_hash = records_hash
end

def pdf_paths
  @pdfs ||= Dir.glob("#{PDF_DIR}/*.pdf")
end

def infer_anum(pdf_path)
  base = File.basename(pdf_path, '.pdf')
  anum = base.sub('_redacted', '').sub('_withdrawal', '')
  anum
end

def pickle(array) 
  array.map { |r| { r['id'].strip => r } }.inject(:merge)
end

def unpickle(hash)
  hash.map { |_k, value| value }.sort_by! { |r| r['id']}
end

def write_to_csv(data, file)
  CSV.open(file, "wb") do |csv|
    csv << data.first.keys
    data.each do |hash|
      csv << hash.values
    end
  end
end

def deduce_page_count(pdf_path)
  GC.start
  PDF::Reader.new(pdf_path).page_count
end


namespace :pdfs do 
  desc 'spit out txt list of anums inferred from pdfs'
  task :anum_txt do
    File.open(ANUM_TXT_FILE, "w") do |file| 
      pdf_paths.map { |path| file.puts infer_anum(path) }
    end
    puts "Done ✓"
  end

  desc 'add page count to csv'
  task :page_count_csv do 
    pdf_paths.each_with_index do |path, i|
      anum = infer_anum path

      next puts "skipping #{anum}" unless records_hash.dig(anum, 'page_count').nil?
      
      page_count = deduce_page_count path
      raise "no anum #{anum} found in hash!!!" unless records_hash.key? anum
      puts "#{anum}: #{page_count} pages"

      records_hash[anum]['page_count'] = page_count
      write_to_csv(unpickle(records_hash), AFILES_CSV_FILE)
    end
  end
  
  desc 'split pdfs to jpgs'
  task :split_jpgs do
    FileUtils.mkdir_p JPG_DIR

    pdf_paths.each_with_index do |path, i|
      anum        = infer_anum path
      page_count  = Integer(records_hash.dig(anum, 'page_count') || deduce_page_count(path))
      dir         = File.join JPG_DIR, anum
     
      FileUtils.mkdir_p dir
    
      (0..page_count - 1).each do |index|
        page_num    = index.to_s.rjust(4, "0")
        page_id     = "#{anum}_#{page_num}"
        target      = File.join dir, "#{page_num}.jpg"

        next if File.file? target
  
        img = Vips::Image.pdfload path, page: index, n: 1, dpi: 300
        img = img.thumbnail_image(2500, height: 10000000) if (img.width > 2500)
        img.jpegsave target
        
        print "writing #{anum} page #{index} / #{page_count}\r"
        $stdout.flush
      end
      
      puts "finished pdf #{i+1}/#{pdf_paths.length} — process is #{(i.to_f / pdf_paths.length.to_f * 100.0).round(1)}% complete    \n"
    end
    puts "Done ✓"
  end
end