class NuffieldScraper < Tess::Scrapers::Scraper
  # This provider has an RSS feed, an iCal, and also uses bits of RDFa. However, neither method gives all information
  # about events we need. iCal does not contain link to the event nor location. RSS feed does not contain end date,
  # and location. Structured data is also patchy, not implemented properly and also missing a few event properties. For
  # this reason, we resorted to parsing good all HTML.
  #
  # Provider provides events as pages which are loaded on demand via AJAX as JSON, containing lists of HTML snippets
  # about events that are then injected into the page directly. We are getting all these pages, extracting HTML
  # snippets from JSON, putting them into a dummy HTML document and then parsing the document to extract the data we
  # need.

  def self.config
    {
        name: "Nuffield Department for Population Health Scraper",
        root_url: "https://www.ndph.ox.ac.uk",
        forthcoming_events_path: "/events?tab=forthcoming&format=json",
        past_events_path: "/events?tab=past&format=json",
        pagination_variable: "b_start:int",
        pagination_increment: 20,
        # address: "Richard Doll Building, University of Oxford",
        # city: "Oxford",
        # country: "United Kingdom",
        # postcode: "OX3 7LF",
        # latitude: 51.752619,
        # longitude: -1.215312
    }
  end

  # Scrapes good all HTML despite having an RSS feed, iCal and rdfa (none of which are implemented properly nor give all
  # event details)
  def scrape
    cp = add_content_provider(Tess::API::ContentProvider.new(
        {title: "Nuffield Department for Population Health",
         url: config[:root_url],
         image_url: "https://www.ndph.ox.ac.uk/images/site-logos/primary-logo",
         description: "Nuffield Department for Population Health undertakes research and trains scientists to seek answers to some of the most important questions about the causes, prevention and treatment of disease to reduce disability and premature death in both the developed and developing worlds.",
         content_provider_type: :organisation,
         keywords: ["HDRUK"]
        }))

    forthcoming_events_url = config[:root_url] + config[:forthcoming_events_path]
    past_events_url = config[:root_url] + config[:past_events_path]

    # Get HTML snippets together for past and future events
    events_html = get_events(forthcoming_events_url) + get_events(past_events_url)

    # Wrap the HTML snippet with events into a dummy HTML doc
    html_text = "<html><head></head><body>#{events_html}</body></html>"
    # Parse the HTML doc
    html_doc = Nokogiri::HTML(StringIO.open(html_text))
    event_divs = html_doc.css("div.listing-item-event")
    event_divs.each do |event_div|
      event_title = event_div.xpath(".//h2/a").try(:text)
      event_url = event_div.xpath('.//h2/a/@href').first.try(:text)
      # Nothing is available for description of the events so using speaker's name (which is also not always available)
      event_speaker = event_div.xpath('.//p[@class="event-speaker"]/a').first.try(:text)
      event_description = "Speaker: " + event_speaker unless event_speaker.nil?
      event_start_date = event_div.xpath('.//p[@class="details"]/span[@itemprop="startDate"]/@content').try(:text)
      event_end_date = event_div.xpath('.//p[@class="details"]/span[@itemprop="endDate"]/@content').try(:text)
      event_venue = event_div.xpath('.//p[@class="details"]/span[@itemprop="location"]').first.try(:text)

      event = Tess::API::Event.new(
          {content_provider: cp,
           title: event_title,
           url: event_url,
           start: event_start_date,
           end: event_end_date,
           description: event_description,
           organizer: 'Nuffield Department for Population Health',
           venue: event_venue,
           country: 'United Kingdom',
           event_types: [:workshops_and_courses], # these are actually seminars - we'd need a new category
           keywords: ["HDRUK"]
          })
      add_event(event)
    end
  end

  private

  # Events (returned as list of HTML snippets) are extracted from JSON that looks like this:
  #      {
  #     "items": [
  #         "\n        \n    <div class=\"listing-item listing-item-event\" itemscope itemprop=\"itemListElement\" itemtype=\"http://schema.org/Event\">\n\n        <div class=\"row\">\n\n            \n            \n            \n\n            <div class=\"col-xs-12\">\n\n                \n                    <div class=\"pull-right\" style=\"margin-left:4px\">\n                        <a href=\"https://www.ndph.ox.ac.uk/events/uvbo-seminar-nutrient-timing-and-human-health/event_ical\">\n                            <i class=\"glyphicon-calendar icon-sm\"></i>\n                        </a>\n                    </div>\n                \n            \n                <h2 class=\"media-heading\">\n                    <a href=\"https://www.ndph.ox.ac.uk/events/uvbo-seminar-nutrient-timing-and-human-health\" title=\"\" itemprop=\"name\" class=\"state-published\">UVBO Seminar - Nutrient timing and human health</a>\n                </h2>\n\n                \n                    <p class=\"event-speaker\">\n                        <a href=\"https://www.ndph.ox.ac.uk/events/uvbo-seminar-nutrient-timing-and-human-health\" title=\"\" itemprop=\"performer\" class=\"state-published\">James Betts, Professor of Metabolic Physiology, University of Bath</a>\n                    </p>\n                \n\n                \n                    <p class=\"categories-list\">\n                        \n\n    \n            \n        \n            <a href=\"search?category=research\" title=\"Research\">\n                <span class=\"label label-primary\">Research</span>\n            </a>\n        \n\n    \n\n\n                    </p>\n                \n\n                <p class=\"details\">\n                    \n                        <span>Thursday, 24 October 2019, 1pm to 2pm</span>\n                    \n                    \n                        <span itemprop=\"startDate\" content=\"2019-10-24T13:00:00\" />\n                    \n                    \n                        <span itemprop=\"endDate\" content=\"2019-10-24T14:00:00\" />\n                    \n                    \n                        @ <span itemprop=\"location\">School of Anthropology, 61 Banbury Road, OX2 6PE</span>\n                     \n                </p>\n\n                \n\n            </div>\n\n        </div>\n\n    </div>\n    \n\n"
  # ],
  #     "more": "\n\n    \n\n",
  #     "msg": ""
  # }
  # New lines are removed and quotes unescaped and events are returned as an HTML string.
  def get_events(url)
    events_json = JSON.parse(open(url).read)
    puts "Reading events from: #{url}"
    html_events = []
    next_items = config[:pagination_increment]
    until events_json["items"].empty?
      html_events += events_json["items"]
      # Get the URL for the next page of results
      uri = URI.parse(url)
      new_query_params = URI.decode_www_form(String(uri.query)) << [config[:pagination_variable], next_items] # fetch next items
      uri.query = URI.encode_www_form(new_query_params)
      next_url = uri.to_s
      puts "Reading events from: #{next_url}"
      events_json = JSON.parse(open(next_url).read)
      next_items += config[:pagination_increment]
    end

    html_chunk = html_events.join("") # flatten all HTML snippets into one big string
    html_chunk = html_chunk.gsub(/\r\n/, " ") # Remove all \r\n new line characters and replace them by one blank character
    html_chunk = html_chunk.gsub(/\n\s*/, "") # Remove all \n characters followed by any number of spaces
    html_chunk = html_chunk.gsub('\\"', '"') # Replace escaped quotes with just a quote character
    return html_chunk
  end
  
end