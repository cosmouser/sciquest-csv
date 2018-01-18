require 'selenium-webdriver'
require 'nokogiri'
require 'csv'

# Login URL:
login_url = 'https://solutions.sciquest.com/apps/Router/Login?OrgName=YourOrgNameHere'

# Enter credentials here:
sq_user = 'username'
sq_pw = 'password'

# Define processing methods
# Returns an array of requisiton numbers, takes a nokogiri document
def generate_req_array(req_src)
  req_links = req_src.css('tbody>tr>td>span>a')
  req_arr = req_links.select {|r| r.text =~ /\d/}
  req_arr.map! {|r| r.text}
  return req_arr
end

def parse_req(reqhtml)
  total_CSS = "td.ForegroundPanel>div>div>div>table>tbody>tr>td>table>tbody>tr>td"
  docsummarybox_CSS = "td.DocSummaryBox>div>table>tbody>tr>td"
  row = []
  # po number
  row.push(reqhtml.css("table>tbody>tr>td>a").select {|a| a.text =~ /^P0\d/}.first.text)
  # cost
  row.push(reqhtml.css(total_CSS)[-2].text.gsub("\n",""))
  # cart name
  row.push(reqhtml.css(docsummarybox_CSS).map {|f| f.text}[1])
  # note
  note_index = reqhtml.css(docsummarybox_CSS).map {|f| f.text}.index("Internal Note")
  row.push(reqhtml.css(docsummarybox_CSS).map {|f| f.text}[note_index + 1])
  # products
  req_products = []
  req_products = reqhtml.css("td.LineSixPack>div").select {|d| d.css("a").size > 1}.map {|a| a.children[1].text.gsub("\n","")}
  row.push(req_products.join(", "))
  # foapals
  req_foapals = []
  req_foapals = reqhtml.css("td.DocSummaryBox>div>table>tbody>tr").select {|r| r.text =~ /^\n\d/}
  req_foapals.map! {|f| f.css("td").map {|t| t.text.gsub(/(\S)\n(\S)/,'\1:\2').gsub(/\n/,"")}}
  row = row + req_foapals.flatten
  return row
end

def get_largest_invoice_date(html_src)
  yui0 = Nokogiri::HTML(html_src).css('table.SearchResults').first
  inv_arr = yui0.children.select {|x| x.class == Nokogiri::XML::Element && x.text =~ /\d/}.map {|y| y.css('td').map {|z| z.text.gsub(/[\n\t ,]/,"")}}
  return inv_arr.sort {|a,b| b[6].to_i <=> a[6].to_i}[0][2]
end

# Define a wait
wait = Selenium::WebDriver::Wait.new(:timeout => 15)
# Initialize the browser
# options = Selenium::WebDriver::Firefox::Options.new(args: ['-headless'])
options = Selenium::WebDriver::Firefox::Options.new
driver = Selenium::WebDriver.for(:firefox, options: options)
puts 'Initializing browser'

######## Log into cruzbuy ########
driver.get(login_url)
input = wait.until {
  element = driver.find_element(name: 'Login_User')
  element if element.displayed?
}
input.send_keys sq_user

input = wait.until {
  element = driver.find_element(name: 'Login_Password')
  element if element.displayed?
}
input.send_keys sq_pw
puts "Logging into #{login_url} as #{sq_user}"
input.submit
input = wait.until {
  element = driver.find_element(name: 'ShopInputForm')
  element if element.displayed?
}
if input.property('method') != "post"
  driver.quit
  raise 'Invalid credentials'
end
##################################

########## Get Req List ##########
driver.get(login_url.gsub(/Login.*$/,"DocumentSearch"))
input = wait.until {
  element = driver.find_element(id: 'requisition_DocSearch_UserSearch_Term_GenUsrSrch_SearchSelection_CurrentUser')
  element if element.displayed?
}
input.click
input = wait.until {
  element = driver.find_element(name: 'ReqStatus_Completed')
  element if element.displayed?
}
driver.execute_script("scroll(0, 250);")
input.click
input = wait.until {
  element = driver.find_element(id: 'Button_Search_2')
  element if element.displayed?
}
input.click
wait.until {
  element = driver.find_element(name: 'GeneralSearch_PageSize')
  element if element.displayed?
}
puts "Loading #{driver.title}"

req_src = Nokogiri::HTML(driver.page_source)
reqs = generate_req_array(req_src)
##################################

######## Make CSV and get reqs ###
filename = "output/cruzbuy_#{Time.now.to_i}.csv"
cruzbuyinfo = CSV.open(filename, 'wb', :encoding => 'utf-8')

reqs.map do |req|
  driver.get('https://solutions.sciquest.com/apps/Router/ReqSummary?ReqId=' + req)
  temp_row = parse_req(Nokogiri::HTML(driver.page_source))
  driver.execute_script("openPO();")
  wait.until {
    driver.title =~ /^Status - PO/
  }
  driver.get(driver.current_url.split('&')[0].gsub("Status","Invoices"))
  if driver.find_elements(:xpath => "//td[@class='Error']/span[@class='FieldOpt']") == []
    cruzbuyinfo << temp_row.unshift(get_largest_invoice_date(driver.page_source))
  else
    cruzbuyinfo << temp_row.unshift("no invoice")
  end
  puts "Added #{temp_row.to_s}"
end
##################################

cruzbuyinfo.close
driver.quit
