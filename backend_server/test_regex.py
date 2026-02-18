
import re

def extract_words(text):
    return set(re.findall(r'\b\w+\b', text.lower()))

question = "Хочу спортивный костюм"
product_name = "Спортивный костюм"

q_words = extract_words(question)
p_words = extract_words(product_name)

print(f"Question words: {q_words}")
print(f"Product words: {p_words}")
print(f"Intersection: {q_words & p_words}")
