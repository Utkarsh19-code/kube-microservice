from flask import Flask, jsonify
app = Flask(__name__)
products = [{"id":1,"name":"Laptop","price":50000},{"id":2,"name":"Keyboard","price":2000},{"id":3,"name":"Mouse","price":800}]
@app.get("/health")
def health(): return jsonify({"status":"UP"})
@app.get("/products")
def products_list(): return jsonify(products)
if __name__ == "__main__": app.run(host="0.0.0.0", port=5000)
