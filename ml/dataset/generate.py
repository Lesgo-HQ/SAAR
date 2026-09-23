import json, random, pathlib
intents = ["order_item","search_item","add_to_cart","change_quantity","select_address","checkout"]
templates = {
 "order_item": ["Order {qty} {item} from {app}", "Buy {item} {qty}", "Get {item} delivered to my {addr}"],
 "search_item": ["Search for {item}", "Find {item} on {app}"],
 "add_to_cart": ["Add {item} to cart", "Add {qty} {item} to cart"],
 "change_quantity": ["Change quantity to {qty}", "Set quantity {qty} for {item}"],
 "select_address": ["Deliver to my {addr}", "Get it delivered to my {addr}"],
 "checkout": ["Checkout", "Proceed to checkout"],
}
items=["rice","milk","bread","eggs","atta","oil","sugar"]
apps=["zepto","amazon","flipkart"]
addrs=["home","office"]
qty=["2","two","2 kg","3 packets"]

out=[]
for intent, tpls in templates.items():
 for tpl in tpls:
  for _ in range(30):
   text=tpl.format(qty=random.choice(qty), item=random.choice(items), app=random.choice(apps), addr=random.choice(addrs))
   slots={}
   if "{item}" in tpl: slots["item"]=random.choice(items)
   if "{qty}" in tpl: slots["quantity"]=2
   if "{addr}" in tpl: slots["address"]=random.choice(addrs)
   out.append({"text":text,"intent":intent,"slots":slots,"app":random.choice(apps),"difficulty":"easy","source":"synthetic"})
unk=["tell me a joke","what is weather","open camera","play music","book a flight"]
for t in unk*10: out.append({"text":t,"intent":"UNKNOWN","slots":{},"difficulty":"easy","source":"synthetic"})
random.shuffle(out)
pathlib.Path("ml/dataset/data.jsonl").write_text("\n".join(json.dumps(x) for x in out))
print(f"generated {len(out)}")
