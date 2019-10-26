require 'icalendar'

class BartsScraper < Tess::Scrapers::Scraper

  def self.config
    {
        name: 'Barts Cancer Institute Scraper',
        calendar: 'https://www.bartscancer.london/events-seminars/__month__/?ical=1&tribe_display=month',
        earliest: Date.parse('2019-01-01')
    }
  end

  def scrape
    cp = add_content_provider(Tess::API::ContentProvider.new(
        { title: "Barts Cancer Institute",
          url: "https://www.bartscancer.london/",
          image_url: "https://www.bartscancer.london/wp-content/uploads/2019/04/CRUK_BARTS_C_Neg_Solid_White_300.png",
          description: "The Barts Cancer Institute (BCI) was created in 2003, and brought together some of the most eminent cancer research teams in London. As part of the Barts and The London School of Medicine and Dentistry, Queen Mary University of London, the BCI has one overriding objective, which is to ensure that the research conducted here is relevant to and will impact on cancer patients.",
          content_provider_type: :organisation
        }))

    date = Date.today

    while date >= config[:earliest] do
      url = config[:calendar].sub('__month__', date.iso8601[0..6])
      file = open_url(url)
      events = Icalendar::Event.parse(file.set_encoding('utf-8'))

      events.each_slice(40) do |batch|
        batch.each do |ical_event|
          begin
            event = { content_provider: cp }
            event[:start]       = ical_event.dtstart.to_datetime unless ical_event.dtstart.blank?
            event[:end]         = ical_event.dtend.to_datetime unless ical_event.dtend.blank?
            event[:title]       = ical_event.summary.try(:to_s).try(:strip)
            event[:description] = ical_event.description.try(:to_s).try(:strip)
            loc = ical_event.location.try(:to_s).try(:strip)
            # Try and hack the address out
            if loc
              parts = loc.split(',')
              postcode_index = parts.index { |part| part.strip.match?(/^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$/) }
              if postcode_index
                event[:country] = 'United Kingdom' # Nowhere else uses postcodes
                event[:postcode] = parts[postcode_index].strip
                event[:city] = parts[postcode_index - 1].strip if parts[postcode_index - 1]
                event[:venue] = parts[0..postcode_index - 2].join(', ').strip if parts[postcode_index - 2]
              else
                event[:venue] = loc
              end
            end
            event[:latitude]    = ical_event.geo.first.to_f unless ical_event.geo.blank?
            event[:longitude]   = ical_event.geo.last.to_f unless ical_event.geo.blank?
            event[:url]         = ical_event.url.try(:to_s)
            event[:event_types] = [:meetings_and_conferences]

            add_event(Tess::API::Event.new(event))
          end
        end
      end

      date = date - 1.month
    end
  end
end
