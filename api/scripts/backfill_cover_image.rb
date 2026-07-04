Card.includes(:styles).find_each do |card|
  next if card.cover_image.attached?

  cover_style = card.styles.find { |style| style.kind == "cover" && style.image.attached? }

  if cover_style
    puts "Backfilling card ##{card.id} with style ##{cover_style.id} image..."
    card.cover_image.attach(
      io: StringIO.new(cover_style.image.download),
      filename: cover_style.image.filename.to_s,
      content_type: cover_style.image.content_type
    )
  else
    puts "No cover style with image for card ##{card.id}, skipping..."
  end
end
