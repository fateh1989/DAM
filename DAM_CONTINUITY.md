# DAM — حالة المشروع المستمرة

> هذا الملف هو مرجع الاستمرار الرسمي لمشروع DAM بين المحادثات. عند التعارض، يؤخذ آخر Commit ناجح وآخر قرار صريح للمستخدم.

## 1) هوية المشروع

- الاسم: **DAM / دم**
- النوع: لعبة استراتيجية وقت حقيقي **RTS** للأندرويد.
- الإلهام: قابلية القراءة، تكوين البيئة، الإيقاع البصري، والإحساس التكتيكي في ألعاب Red Alert الكلاسيكية.
- القاعدة: **لا يتم نسخ أصول Red Alert أو خرائطها أو موديلاتها أو قواعدها المحمية**. نأخذ مبادئ التصميم فقط.
- العالم الحالي: **سوريا فقط**، 14 محافظة، بدل توسيع النطاق جغرافيًا قبل الوصول إلى جودة عالية.
- البيانات الجغرافية تبقى حقيقية قدر ما تسمح المصادر؛ التشكيل البصري يكون RTS واضحًا ومقروءًا.

## 2) فلسفة التصميم

الهدف ليس صنع عارض خرائط. الهدف تحويل الجغرافيا الحقيقية إلى **ساحة قتال RTS قابلة للقراءة**:

- التضاريس والارتفاعات والطرق والمباني والمياه من مصادر حقيقية.
- الشكل النهائي للأرض، التباين، الجروف، الأشجار، الحقول، الضفاف، الإضاءة والظلال يتم Art Direction لها بأسلوب RTS.
- لا يتم ادعاء دقة غير موجودة في المصدر. مثال: مضلع الغابة حقيقي من المصدر، لكن مواضع الأشجار داخله قد تكون إجرائية للعرض.

## 3) الحالة التقنية الحالية

### المحرك
- Godot: **4.7.2 Stable**
- Renderer: **Mobile / Vulkan**
- Android: arm64 فقط حاليًا.
- Package: **com.fateh1989.dam**
- إصدار التطبيق الحالي بعد ترقية Native Core: **0.3.0 / code 3**
- نفس debug signing identity السابقة محفوظة في CI عبر صورة البناء المثبتة بالـdigest.

### CI
الملف:
`.github/workflows/android-build.yml`

الـCI يقوم بـ:
1. Checkout
2. تثبيت Godot 4.7.2 الرسمي + Export Templates
3. إعداد Android SDK 35 + Build Tools 35.0.1
4. إعداد NDK r28b لمسار C++/GDExtension
5. بناء DAM Native Core
6. Engine smoke
7. Native Core smoke
8. تجميع بيانات 14 محافظة سورية
9. Import
10. Terrain smoke
11. Syria data smoke
12. Aleppo runtime smoke
13. Export APK
14. Verify APK
15. Upload artifact

### آخر Build مؤكد ناجح قبل Native Core
- Build #33
- Commit: `587669fa6f17878e31c3b9ab2fd0adbb7b8e96b1`
- Godot 4.7.2 + Mobile/Vulkan + Terrain v2 نجح فعليًا على الهاتف، والمستخدم قال إنه **أفضل كثيرًا من الوضع السابق**.

### Native Core
بدأ الانتقال إلى قلب C++ حقيقي:
- المسار: `native/`
- التقنية: **C++ / GDExtension**
- أول Hot Path نُقل إلى C++:
  - متوسط ارتفاع الخلايا
  - حساب الميل Slope
  - اكتشاف Cliff-edge candidates
- GDScript fallback موجود فقط لسهولة تحرير المشروع.
- CI مطلوب منه تحميل DAMNativeCore فعليًا، وليس مجرد وجود الملفات.
- Commit Native Core v1:
  `c64901b84c83f5b2e9459ea6b0c35d9457355cdc`
- Build المرتبط عند إنشاء هذا المرجع: **#34**، ويجب فحص نتيجته قبل الادعاء بالنجاح.

## 4) Terrain v2

الملفات الأساسية:
- `source/world/MiddleEastTerrain.gd`
- `source/world/MiddleEastTerrain.tscn`
- `source/world/CompileSyria.py`
- `source/world/SyriaDataSmoke.gd`
- `source/world/AleppoSmoke.gd`

### ما تم
- DEM حقيقي للارتفاع.
- تقسيم الارتفاع إلى خلايا RTS.
- ألوان أرض RTS عالية التباين.
- Ground breakup / patches بدل لون مسطح.
- جروف صخرية مرئية عند الفروق الكبيرة.
- طرق بعرض حسب الصنف + Road shoulders.
- مياه + Water banks.
- Land-cover من OSM داخل القطاعات:
  - forest
  - orchard
  - farmland
  - meadow
  - scrub
  - park
- أشجار إجرائية داخل مضلعات الغطاء النباتي.
- MultiMesh / GPU Instancing للأشجار.
- إضاءة واتجاه شمس وظلال أوضح.
- زاوية كاميرا أقرب لقراءة RTS.

### ملاحظة مهمة
القطاعات الحالية ليست كامل مساحة كل محافظة بالتفصيل. كل محافظة لها **قطاع اختبار تفصيلي حول مركزها** ضمن الحدود المحددة في compiler. لا يجوز وصفها بأنها تغطية تفصيلية كاملة للمحافظة.

## 5) بيانات سوريا

عدد المحافظات: 14
- دمشق
- ريف دمشق
- حلب
- حمص
- حماة
- اللاذقية
- طرطوس
- إدلب
- الرقة
- دير الزور
- الحسكة
- درعا
- السويداء
- القنيطرة

الافتراضي حاليًا: **حلب** باعتبارها مختبر الجودة.

المصدر الأساسي للطرق/المباني/المياه/land-cover الحالي:
- OpenStreetMap عبر Geofabrik Syria PBF.

DEM الحالي:
- Terrarium elevation tiles.

يجب التحقق من الترخيص/المصدر قبل أي ترحيل إنتاجي كبير أو حزم Offline كاملة.

## 6) قواعد الأداء

- ممنوع إنشاء Node مستقل لكل شجرة/طريق/مبنى على نطاق كبير.
- الطرق والمباني والمياه مبنية على Batching.
- الأشجار عبر MultiMesh.
- الهدف التالي: Chunk Renderer حقيقي + Culling + LOD.
- أي توسعة في التفاصيل يجب ألا تعيد مشكلة آلاف Nodes أو إعادة بناء العالم كاملًا عند كل حركة.
- الحفاظ على world origin قريب من الكاميرا لتقليل مشاكل الدقة العددية.

## 7) اتجاه المحرك

المعمارية المستهدفة:

```
Godot Shell / UI / Input
        ↓
DAM Native Core (C++)
        ↓
Chunk World
        ├── Terrain cells
        ├── Height / slope / cliff
        ├── Landcover
        ├── Visibility / culling
        ├── Navigation
        └── Simulation hot paths
        ↓
DAM Renderer
        ├── Batched meshes
        ├── MultiMesh
        ├── LOD
        ├── Culling
        ├── Materials
        ├── Shadows
        └── Atmosphere
```

## 8) الخطة التالية المعتمدة

بعد إثبات Native Core v1 على Android:

1. **Chunk Renderer**
   - تقسيم العالم إلى Chunks.
   - بناء/تحديث الـChunk فقط عند الحاجة.
   - عدم إعادة بناء غير المرئي.

2. **Culling**
   - إيقاف رسم Chunks خارج الكاميرا.
   - Distance culling للتفاصيل الصغيرة.

3. **LOD**
   - قرب: أعلى جودة.
   - وسط: meshes أبسط.
   - بعيد: impostors / macro representation.

4. نقل المزيد من Hot Paths إلى C++:
   - Terrain geometry generation
   - chunk visibility
   - pathfinding
   - large-unit simulation

5. بعد تثبيت الأداء:
   - رفع جودة الأرض السورية أكثر:
     - حقول وبساتين أكثر واقعية
     - أنواع نباتات إقليمية
     - صخور ووديان
     - ضفاف وأنهار
     - Macrotexture وdetail materials
     - cliffs أفضل
     - إضاءة/ضباب/جو

## 9) الأنظمة المؤجلة

لا يتم تشتيت العمل بها قبل تثبيت الأرض والمحرك:

- Units
- Combat
- Economy
- Logistics
- AI
- Fog of War
- Persistent destruction
- Full campaign
- UI gameplay المتقدم

ستعود لاحقًا بعد أن يصبح العالم والمحرك أساسًا قويًا.

## 10) أهداف اللعب طويلة المدى

- RTS مستمر Persistent World / Campaign.
- الهزيمة لا تعني نهاية اللعبة بالكامل.
- موارد، إمداد، ذخيرة، وقود، إصلاح، نقل.
- ضرر ودمار مستمر.
- جيوش وتحركات وتشكيلات وأوامر.
- ذكاء اصطناعي للتخطيط والاستطلاع والدفاع والالتفاف والانسحاب.
- قابلية قراءة عالية على شاشة الهاتف.
- إحساس RTS كلاسيكي قوي ولكن بهوية DAM الأصلية.

## 11) قواعد العمل بين المحادثات

- لا تبدأ DAM من الصفر.
- لا تخلطه مع YM أو RUN أو مقاتل أو أي مشروع آخر.
- قبل تعديل الكود: افحص الفرع والـcommit الحاليين.
- بعد التعديل:
  1. Commit
  2. فحص GitHub Actions
  3. قراءة الخطأ الحقيقي إذا فشل
  4. عدم التخمين
  5. عدم قول "نجح" إلا بعد نجاح CI
  6. عند طلب APK: تنزيل Artifact الصحيح، استخراجه، التحقق منه، ثم إعطاء الرابط.
- آخر قرار للمستخدم يتغلب على أي قرار أقدم.
- زمن الوصول لاختبار فعلي مهم؛ اختر خطوات تعطي نتيجة قابلة للتجربة بسرعة.


### Strategic zoom wheel

The Syria world HUD now includes an always-visible vertical zoom wheel. It covers the practical strategic range from national overview to town-level map detail. Dragging the wheel to its Syria end recenters the camera on the Syria region so the country can be viewed as a whole. Governorate selection remains independent. Moving the wheel while in local 3D terrain mode returns to the strategic map and applies the requested zoom.


## 12) القرار البصري الجديد — DAM Multi-Scale RTS Rendering

تمت مراجعة شكل اللعبة بعد اختبار رؤية سوريا كاملة من مستوى زوم بعيد. النتيجة الأساسية: لا يجوز استخدام نفس تفاصيل العرض التكتيكي من مستوى البلدة حتى مستوى سوريا كلها، لأن ذلك يحول المشهد البعيد إلى مربعات وضوضاء بصرية ويجعل DAM تبدو كعارض GIS بدل لعبة RTS.

### الهدف الفني
الحفاظ على الحقيقة الجغرافية من DEM وOSM، لكن إخراجها بأسلوب RTS واضح وموجه فنياً قريب في فلسفته من Red Alert من حيث:
- وضوح الأرض والوحدات.
- تباين لوني مقصود.
- جروف وحدود ارتفاع مقروءة.
- طرق أوضح من الواقع قليلاً عند الحاجة للعب.
- نباتات في كتل وصفوف وفراغات بدل الضوضاء العشوائية.
- إضاءة وظلال تخدم القراءة التكتيكية قبل الواقعية الفوتوغرافية.
- عدم نسخ أصول أو خامات أو خرائط محمية.

### مستويات العرض الثلاثة
1. **Strategic — سوريا كاملة**
   - Macro Terrain مبسط.
   - الجبال والسهول والأودية الرئيسية.
   - كتل زراعية/صحراوية/جبلية/حضرية كبيرة.
   - المدن الكبرى والأنهار والطرق الرئيسية.
   - لا أشجار فردية ولا مبانٍ صغيرة ولا جروف دقيقة.

2. **Regional — محافظة/منطقة**
   - تفاصيل DEM أعلى.
   - الطرق الرئيسية والثانوية المهمة.
   - المدن ككتل عمرانية أوضح.
   - الغابات والبساتين والحقول الكبرى.
   - الجروف الواسعة والتضاريس الرئيسية.
   - تقليل التفاصيل الصغيرة التي لا تفيد على هذا المقياس.

3. **Tactical — بلدة/ساحة معركة**
   - Terrain الكامل.
   - الجروف Top/Face/Base/Ramps.
   - الأشجار والبساتين والحقول.
   - الطرق بأكتافها.
   - المباني والمياه.
   - الظلال الحية والوحدات والعناصر القابلة للعب.

### صور الأقمار الصناعية
قرار العمل الحالي:
- لا تستخدم صور الأقمار الصناعية الخام كخلفية تكتيكية نهائية.
- تستخدم كمرجع بصري وبياني للمناطق والألوان والأنماط الزراعية والعمرانية.
- يمكن استخدامها في Strategic/Regional بعد معالجة فنية قوية كـ Macro Layer أو مرجع لتوليد الـ masks/splat maps.
- عند الاقتراب إلى Tactical تتلاشى الصورة المعالجة تدريجياً لصالح رسوم DAM نفسها.

### قاعدة الرسم
```
DEM + OSM + Satellite Reference
          ↓
Classification / Masks
          ↓
DAM Art Direction
          ↓
Strategic / Regional / Tactical LOD
          ↓
RTS Terrain + Cliffs + Roads + Vegetation + Lighting
```

### Palette مبدئية للاستشارة وليست نهائية
- Grass: #4A6B3D
- Dry Grass: #A69258
- Soil: #6B4F3A
- Rock: #5A6268
- Road asphalt: #333333
- Road concrete/dust: #B5A896
- Water: #2C5E7A
- Forest: #2B4224
- Orchard: #556B2F
- Urban: #8C8275
- Desert: #C2A676

هذه الألوان ليست ملزمة؛ يتم اعتمادها فقط بعد اختبار بصري فعلي على الهاتف.

### ما اتفقنا ألا نثبته دون قياس
- حجم الـChunk (مثل 64×64m) ليس قراراً نهائياً.
- عدد الأشجار أو مسافات LOD ليست أرقاماً ثابتة.
- زاوية الشمس 35° وقوة الظلال ليست قوانين؛ تقاس بصرياً.
- عدد Texture Samples وحدود FPS يجب قياسها على الجهاز، لا اعتمادها من استشارة.
- الطرق الحقيقية لا تُجبر على زوايا قائمة؛ نحافظ على مسارها ونحسن قراءتها فقط.

### أولويات التنفيذ البصري
1. إصلاح شكل **سوريا كاملة** أولاً كـ Strategic View حقيقي، بدون مربعات Terrain التكتيكية.
2. بناء Macro Terrain / Macro Material يعتمد على البيانات الحقيقية.
3. إضافة انتقال تدريجي بين Strategic → Regional → Tactical.
4. بناء Terrain Material System مخصص:
   - texture arrays أو بديل مناسب بعد القياس
   - splat/weight masks
   - slope-based rock
   - macro variation
   - detail textures
5. تطوير Cliff System التكتيكي الكامل:
   - Top
   - Face
   - Base
   - Ramp
   - Passability
6. تحسين النباتات:
   - clusters
   - clearings
   - forest edges
   - orchard rows
   - MultiMesh + LOD
7. تحسين الطرق والمياه والإضاءة بعد تثبيت الأرض.

### نقطة الاختبار البصري المرجعية
لا يتم تعميم أي نظام جديد على كامل سوريا قبل أن ينجح بصرياً في قطاع مرجعي واحد، والأولوية الحالية لحلب. يتم اختبار:
- قراءة الطريق.
- قراءة الجرف.
- وضوح الوحدة فوق الأرض.
- جودة الأرض من مسافة كاميرا RTS.
- الانتقال عند التكبير/التصغير.

القاعدة: **إذا بدا المشهد مثل GIS أو صورة قمر صناعي خام، فالأسلوب فشل. إذا احتفظ بالحقيقة الجغرافية لكنه يقرأ فوراً كلعبة RTS، فنحن في الاتجاه الصحيح.**


### تنفيذ Strategic Visual Pass v1

بدأ التنفيذ الفعلي للاتجاه البصري متعدد المقاييس. عند مستوى سوريا الكامل (Zoom 6):
- العرض لم يعد يستخدم بلاطات OSM الشارعية كصورة GIS.
- يتم تحميل DEM منخفض الزوم من Terrarium.
- يتم رسم Macro Terrain مبسط 28×28 خلية لكل بلاطة.
- ألوان العرض الاستراتيجي تستخدم Palette DAM المبدئية مع Hillshade اتجاهي مستخرج من فروق الارتفاع الحقيقي.
- الكاميرا الاستراتيجية تضبط حجمها من أبعاد سوريا الجغرافية بدلاً من حجم خمسة بلاطات خريطة، حتى تملأ سوريا الشاشة بصورة أفضل.
- يتم تحميل 3×3 بلاطات فقط في Strategic لتقليل الشبكة والطلبات.
- Zoom 7–10 يبقى مؤقتاً على الخريطة الحالية إلى أن يُبنى Regional Renderer.
- Tactical Terrain لم يتغير في هذه الخطوة.

هذا هو أول Pass تجريبي، وليس الشكل النهائي. الحكم النهائي يكون من لقطة الهاتف بعد Build أخضر.


### تنفيذ استشارة Gemini — Global Macro Texture + Stylized Height-Color Shader

تم تنفيذ المقترح كما هو كمرحلة Strategic:
- Global Macro Texture واحدة بحجم 2048×2048 تغطي نطاق سوريا.
- توليدها أثناء CI من DEM Terrarium الحقيقي مع تصنيف لوني عسكري وفق Palette DAM، وإضافة landcover واسع من OSM للغابات والبساتين والزراعة.
- Global Macro Height Map منفصلة لإعادة بناء relief موحد لسوريا.
- Macro Variation Texture منخفضة التردد لكسر التكرار.
- Strategic Syria أصبحت Mesh واحدة موحدة 96×96 بدلاً من بلاطات العرض البعيدة.
- Shader يستخدم World-Space UV على كامل سوريا، Macro Variation، Hillshade باتجاه عالمي، وDistance Fade.
- Color Grading موحد عبر WorldEnvironment (contrast/saturation).
- العرض الاستراتيجي لا يحمل الأشجار الفردية أو المباني أو الطرق الفرعية.
- CI يتحقق من توليد الأصول ثم يشغل StrategicViewSmoke للتأكد من وجود Global Macro Mesh + Shader.

الحكم البصري النهائي يبقى من الهاتف بعد Build أخضر.


### Tactical Ground Visual Pass — مرجع DAM البصري

بعد مقارنة Build #39 بصور الهاتف وبالمرجع البصري الجديد، بدأ تحويل REAL TERRAIN نفسه:
- الـDEM ما زال مصدر الارتفاع الحقيقي، لكنه لم يعد يُعرض كدرجات 20m/مربعات ملونة.
- Rendering يستخدم floating DEM مستمر مع تنعيم داخلي، مع إبقاء حدود البلاطات على قيم DEM الأصلية لتقليل seams.
- شبكة الـ20m المنفصلة بقيت فقط للتحليل والمنطق التكتيكي.
- تمت إضافة TacticalGround shader يستخدم UV جغرافي موحد عبر سوريا كلها، فلا يبدأ النمط من جديد عند كل tile.
- الأرض تمزج عشب/عشب جاف/تراب بشكل عضوي مستمر، مع Macro Texture الجغرافية وSlope-based Rock.
- أوقفت cliff quads القديمة مؤقتاً لأنها كانت تولد مثلثات/فراغات سوداء؛ بيانات cliff candidates باقية لبناء Rock Cliff Mesh لاحقاً.
- الطرق التكتيكية تحولت من خطوط OSM سوداء إلى طريق ترابي دافئ بكتف أغمق.
- الماء أصبح أزرق-أخضر أقرب للمرجع.
- AleppoSmoke يتحقق الآن أن Shader الأرض التكتيكية مفعّل فعلاً.

المرجع البصري المستهدف: أرض RTS غنية ومتصلة، عشب/تراب/صخور/طرق مدمجة، مع DEM كهيكل تحت الأرض وليس كمربعات مرئية.


## New DAM direction — Syria RTS, no real terrain requirement

User explicitly reduced the geographic requirement:
- Keep Syria strategic geography and governorate/city anchors accurate.
- Real DEM/topography is NOT required.
- Local roads, hills, forests, villages and battlefield terrain may be fully art-directed for gameplay and visual quality.
- Visual terrain should be substantially prettier than classic Red Alert-era terrain.
- Armies/vehicles should later use a more realistic visual language.

First implementation of this direction:
- Tactical mode no longer downloads Terrarium DEM.
- Tactical terrain height is deterministic fictional rolling terrain, seamless across local tiles.
- Tactical shader no longer samples the real Syria macro texture.
- OSM local roads/buildings/landcover are no longer required for battlefield rendering.
- Added designed dirt roads, road shoulders, creek, compact settlement and vegetation clusters.
- Governorate/city anchors were refreshed from GeoNames coordinates where available; Rif Dimashq uses Douma as the displayed anchor.
- HUD now calls the mode RTS TERRAIN rather than REAL TERRAIN.
