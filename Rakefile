require 'fileutils'
require 'yaml'


CONFIG          = YAML.load_file 'config.yml'
RW_DIR          = File.dirname CONFIG['source_dir']
PDF_DIR         = File.join RW_DIR, 'pdfs'
JPG_DIR         = File.join RW_DIR, 'jpgs'
AP_SRC_DIR      = './src'
ANUM_TXT_FILE   = File.join RW_DIR, 'anumbers.txt'
AFILES_CSV_FILE = File.join AP_SRC_DIR, 'afiles.csv'
PAGES_CSV_FILE  = File.join AP_SRC_DIR, 'pages.csv'

Dir.glob("lib/tasks/*.rake").each { |r| load r }



