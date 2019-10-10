require 'nokogiri'

class UclScraper < Tess::Scrapers::Scraper
  def self.config
    {
        name: 'University College London Scraper',
        root_url: 'https://www.ucl.ac.uk/short-courses/search-courses',
        query_url: 'https://search2-push.ucl.ac.uk/s/search.json?collection=drupal-push-short-courses-short_course&meta_UclSubject_sand=%22Healthcare+and+medical%22&meta_UclSubject_sand=%22Health+informatics%22&sort=title'
    }
  end

  def scrape
    cp = add_content_provider(Tess::API::ContentProvider.new({
         title: "University College London", #name
         url: config[:root_url], #url
         image_url: "https://cdn.ucl.ac.uk/indigo/images/twitter-card-ucl-logo.png",
         description: "Founded in 1826 in the heart of London, UCL is London's leading multidisciplinary university, with more than 13,000 staff and 42,000 students from 150 different countries.",
         content_provider_type: :organisation,
         keywords: ["HDRUK"]
     }))


    json = JSON.parse(open_url(config[:query_url]).read)
    json['response']['resultPacket']['results'].each do |result|
        metadata = result['metaData']
        # subcourses
        #courses_page = open_url(metadata['LiveUrl'])
        #page = Nokogiri::HTML.parse(courses_page)
        #courses = page.xpath('//*[@id="accordion"]/dl/dt')

        event = Tess::API::Event.new
        event.title = metadata['FeedTitle']
        event.url = result['liveUrl']
        event.description = metadata['c']
        event.keywords = metadata['UclSubject'].split("|")
        event.start = metadata['d']
        event.content_provider = cp
        add_event(event)
    end

  end
end

=begin
require 'open-uri'
require 'nokogiri'
a = Nokogiri::HTML.parse(open('https://www.ucl.ac.uk/short-courses/search-courses/harnessing-electronic-health-records-ehr-research-series-short-courses'))
a.xpath('//*[@id="accordion"]/dl/dt')
=end
