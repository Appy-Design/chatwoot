json.id article.id
json.slug article.slug
json.title article.title
json.content article.content
json.description article.description
json.status article.status
json.position article.position
json.account_id article.account_id
json.updated_at article.updated_at.to_i
json.meta article.meta
json.locale article.locale
json.associated_article_id article.associated_article_id

if article.root_article.present?
  json.root_article do
    json.partial! 'api/v1/accounts/articles/associated_article', formats: [:json], article: article.root_article
  end
end

json.category do
  json.id article.category_id
  json.name article.category&.name
  json.slug article.category&.slug
  json.locale article.category&.locale
end

json.views article.views

if article.author.present?
  json.author do
    json.partial! 'api/v1/models/agent', formats: [:json], resource: article.author
  end
end

json.associated_articles do
  if article.associated_articles.any?
    json.array! article.associated_articles.each do |associated_article|
      json.partial! 'api/v1/accounts/articles/associated_article', formats: [:json], article: associated_article
    end
  end
end
