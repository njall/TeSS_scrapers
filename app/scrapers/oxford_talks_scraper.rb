#HDRUK
# MedSci Oxford Talks
require 'nokogiri'

class OxfordTalksScraper < Tess::Scrapers::Scraper
  def self.config
    {
        name: 'Oxford Talks Scraper',
        url: 'https://talks.ox.ac.uk/', 
        api_url: 'https://talks.ox.ac.uk/api/talks/search?from=today&topic=',
        topics: ['http://id.worldcat.org/fast/914091']
    }
  end

  def scrape
    cp = add_content_provider(Tess::API::ContentProvider.new({
         title: "Oxford Talks", #name
         url: config[:url], #url
         image_url: "https://talks.ox.ac.uk/static/images/ox_brand6_rev_rect.gif",
         description: "",
         content_provider_type: :institution,
         keywords: ["HDRUK"]
     }))

    config[:topics].each do |topic|
        query_url = '' + config[:api_url] + topic
        data = open(query_url).read
        json = JSON.parse(data)

        talks = json["_embedded"]["talks"]
        talks.each do |talk|
          puts talk["title_display"]
          puts talk["start"]
          puts talk["end"]
          puts talk["description"]
          puts talk["venue"]

          event_topics = talk["_embedded"]["topics"].each do |event_topic|
            puts event_topic['label']
          end
        end
    end
  end
end
