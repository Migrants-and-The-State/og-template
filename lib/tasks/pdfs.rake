require 'pdf-reader'
require 'vips'

def pdf_paths
  @pdfs ||= Dir.glob("#{PDF_DIR}/*.pdf")
end

def infer_anum(pdf_path)
  base = File.basename(pdf_path, '.pdf')
  anum = base.sub('_redacted', '').sub('_withdrawal', '')
  anum
end

namespace :pdfs do 
  desc 'spit out txt list of anums inferred from pdfs'
  task :anum_txt do
    File.open(ANUM_TXT_FILE, "w") do |file| 
      pdf_paths.map { |path| file.puts infer_anum(path) }
    end
    puts "Done ✓"
  end
  
  desc 'split pdfs to jpgs, capture results in csvs'
  task :jpg_csv do
    File.open(AFILES_CSV_FILE, 'w') { |file| file.puts("id,label,og_pdf_id,page_count") }
    File.open(PAGES_CSV_FILE, 'w') { |file| file.puts("id,label,a_number,page_number,extracted_text") }
    FileUtils.mkdir_p JPG_DIR

    pdf_paths.each_with_index do |path, i|
      GC.start
      reader      = PDF::Reader.new path
      page_count  = reader.page_count
      anum        = infer_anum path
      dir         = File.join JPG_DIR, anum
      pdf_data    = [anum,anum,File.basename(path, '.pdf'),page_count]
    
      File.open(AFILES_CSV_FILE, 'a') { |f| f.puts pdf_data.join(',') } 
      FileUtils.mkdir_p dir
    
      (0..page_count - 1).each do |index|
        page_num    = index.to_s.rjust(4, "0")
        page_id     = "#{anum}_#{page_num}"
        target      = File.join dir, "#{page_num}.jpg"
        text        = reader.pages[index].text.to_s.gsub(/\R+/, "|").gsub('"', "'")
        page_data   = [page_id,page_id,anum,page_num,"\"#{text}\""]
    
        File.open(PAGES_CSV_FILE, "a") { |f| f.puts page_data.join(',') }
    
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