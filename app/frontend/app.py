import os
import requests
from flask import Flask, render_template_string
app = Flask(__name__)
PRODUCT_API_URL = os.getenv("PRODUCT_API_URL", "http://product-api:5000")
HTML = """<!doctype html><html><head><title>Kubernetes Microservices Demo</title>
<style>body{font-family:Arial;max-width:800px;margin:50px auto;padding:0 20px}.product{border:1px solid #ddd;padding:16px;margin:12px 0;border-radius:8px}code{background:#f3f3f3;padding:2px 5px}</style>
</head><body><h1>Kubernetes Microservices Demo</h1>
<p>Frontend → <code>product-api</code> Kubernetes Service → Product API</p>
{% for p in products %}<div class="product"><strong>{{ p.name }}</strong><br>Price: ₹{{ p.price }}</div>{% endfor %}
</body></html>"""
@app.get("/")
def home():
    r = requests.get(f"{PRODUCT_API_URL}/products", timeout=5)
    r.raise_for_status()
    return render_template_string(HTML, products=r.json())
@app.get("/health")
def health(): return {"status":"UP"}
if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
