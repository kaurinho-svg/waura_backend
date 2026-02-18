import os
import json
from pathlib import Path
from .meili import client, MEILI_INDEX

def main():
    # 1) индекс
    try:
        client.get_index(MEILI_INDEX)
        print(f"Index '{MEILI_INDEX}' already exists")
    except Exception:
        client.create_index(MEILI_INDEX, {"primaryKey": "id"})
        print(f"Created index '{MEILI_INDEX}'")

    index = client.index(MEILI_INDEX)

    # 2) какие поля ищем
    index.update_searchable_attributes([
        "title", "brand", "category", "gender", "color", "material",
        "tags", "style_tags"
    ])

    # 3) по чему фильтруем
    index.update_filterable_attributes([
        "brand", "category", "gender", "color", "price", "style_tags"
    ])

    # 4) сортировки
    index.update_sortable_attributes(["price"])

    # 5) синонимы (минимум для старта)
    index.update_synonyms({
        "кроссы": ["кроссовки", "кеды", "sneakers"],
    	"кроссовки": ["sneakers"],
    	"худи": ["hoodie", "толстовка"],
   	"толстовка": ["hoodie", "sweatshirt"],
    	"пальто": ["coat", "overcoat"],
    	"coat": ["пальто"],
    	"куртка": ["jacket"],
    	"джинсы": ["jeans", "denim"],
    })

    # 6) загрузка данных (положи свой json рядом, или замени на БД)
    sample_path = Path(__file__).resolve().parent / "sample_catalog.json"
    data = json.loads(sample_path.read_text(encoding="utf-8"))

    task = index.add_documents(data)
    print("Add documents task:", task)
    print("Done.")

if __name__ == "__main__":
    main()