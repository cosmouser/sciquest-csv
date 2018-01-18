# sciquest-csv
sciquest-csv is an order scraping project. It takes a list of sciquest/jaggaer/cruzbuy requisitions and collects data from each one to make rows in a local csv file.

## Installation
The scraper requires selenium-webdriver, which requires geckodriver.

If you're on a mac and have brew, you can install geckodriver like so:
```
brew install geckodriver
```
Then, clone the repository and install the gems:
```
bundle install
```

## Usage
After installation, you should have a sciquest-csv folder with a output folder inside it.

Open sciquest-csv.rb and put in your credentials and the url to the login page.

Save the file and then
```
ruby sciquest-csv.rb
```

The end product will be in the output folder.

