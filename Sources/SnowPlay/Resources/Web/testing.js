'use strict';
(()=>{
const tests=[
 {
  "title": "Подключение и слои macOS",
  "action": "Открой пульт из снежинки в menu bar. Поставь рядом Safari или Finder и оставь видимую часть рабочего стола.",
  "expected": "Пять вкладок работают. Летящий снег виден за окнами; текст и кнопки приложений чистые и принимают клики."
 },
 {
  "title": "Количество и размер хлопьев",
  "action": "В Snow сравни 0% и 100%, затем размер 1× и 3×. Верни размер 2,5×.",
  "expected": "При 100% заметно больше снега; хлопья различаются размером и прозрачностью. Лежащий снег не исчезает при 0%."
 },
 {
  "title": "Скорость и ветер",
  "action": "Сравни скорость 0,25× и 2,5×. Проведи стрелку направления слева направо; проверь клавиши ← →.",
  "expected": "Снег плавно меняет скорость и направление. После открытия пульта значения сохранены."
 },
 {
  "title": "Сугроб и курсор",
  "action": "Подожди накопления. Медленно проведи курсором по нижнему снегу, затем быстро взмахни и остановись.",
  "expected": "Медленно: борозда и снежные плечи. Быстро: короткий разлёт и возврат частиц. Снег оседает, а не стирается."
 },
 {
  "title": "Обвал с окна",
  "action": "Включи небольшой снег на окнах. Дай ему накопиться, затем перемести, уменьши и закрой тестовое окно.",
  "expected": "Кромка следует окну без большого отрыва. Потерявшие опору комки ускоряются, вращаются и пополняют нижний сугроб."
 },
 {
  "title": "Снегоуборщик",
  "action": "В Snow проверь картинку и вызови снегоуборщик при накопленном снеге. Повтори нажатие в процессе.",
  "expected": "Модель загружена. Вращаются колёса, перед ковшом растёт вал, за ним снег убран. Вторая машина не появляется."
 },
 {
  "title": "Доставка ёлки",
  "action": "В Tree выбери размер, нажми «Привезти ёлку» и укажи свободное место внизу. Проверь все три размера.",
  "expected": "Около пяти секунд: машина подъезжает, гном берёт ёлку рукой, ставит, возвращается и уезжает. Ёлка не возникает заранее."
 },
 {
  "title": "Подарки и украшения",
  "action": "Добавь подарки у ёлки. Выбери звезду, шарики и гирлянду, затем перетащи игрушку к другой ветке.",
  "expected": "Подарки устанавливаются короткой анимацией. Игрушки закреплены на ветках; открытый подарок исчезает после трёх цветных салютов."
 },
 {
  "title": "Удаление ёлки",
  "action": "Нажми «Срубить ёлку», несколько раз повтори нажатие и дождись конца. При желании повтори установку и удаление.",
  "expected": "Один Йети делает три замаха. Ёлка падает, снег взлетает, украшения убраны, Йети подпрыгивает и уходит. Нет зависших объектов."
 },
 {
  "title": "Автоматическая сборка снеговика",
  "action": "В Snowman & Yeti оставь автоматическую сборку включённой. Нажми «Слепить снеговика» и выбери нижний снег.",
  "expected": "Три шара растут, катятся, складываются; затем появляются детали. Готовый снеговик моргает и покачивается. Нужен запас снега."
 },
 {
  "title": "Ручная лепка",
  "action": "Убери готового снеговика. Выключи автоматическую сборку и нажми лепку. Перчаткой прокати три шара по нижнему снегу.",
  "expected": "Отдельного окна для лепки нет. Шары растут за счёт сугроба и собираются. Нажатие «Готово» возвращает обычный курсор."
 },
 {
  "title": "Снежок в снеговика",
  "action": "Нажми «Бросить снежок в снеговика» и повтори нажатие в полёте.",
  "expected": "Йети набирает снег, замахивается и выпускает снежок из лапы. Попадание разбивает снеговика на три кома; масса возвращается вниз."
 },
 {
  "title": "Сюрприз и уклонение",
  "action": "По очереди вызови сюрприз и уклонение. В уклонении уведи курсор из отмеченного круга до прилёта.",
  "expected": "Йети выбегает и бросает по дуге. Есть короткий всплеск и реакция на уклонение. Сценка заканчивается сама."
 },
 {
  "title": "Покормить Йети",
  "action": "Вызови кормление, перетащи настоящий снежок к лапе и отпусти. Также попробуй отпустить далеко от руки.",
  "expected": "У руки Йети ловит, подбрасывает и прячет снежок. Неудачный перенос возвращает его; отмена возвращает зарезервированный снег."
 },
 {
  "title": "Дуэль и баллистика",
  "action": "Освободи участок рабочего стола, начни Duel. Попробуй слабый, средний и сильный броски. Один ход пропусти.",
  "expected": "У обоих по 5 HP, очередность соблюдается. Снежок может недолететь, попасть или перелететь; попадание снимает 1 HP. Лимит хода — 5 секунд. Стрелка и траектория следуют за курсором вверх/вниз; один клик — бросок."
 },
 {
  "title": "Дуэль: концовки и выход",
  "action": "Выиграй точными бросками, затем проиграй, пропуская ходы. Проверь Escape и повторный запуск.",
  "expected": "При победе два гнома поднимают и уносят Йети. При поражении гнома грузят на ту же машину. Выход убирает игровое поле и сохраняет декор."
 },
 {
  "title": "Парашют и отсутствие автосанты",
  "action": "В Snow нажми «Подарок». Проверь посадку и таймер. Затем оставь приложение без команд на пять минут.",
  "expected": "Спуск около 4 секунд, таймер до ближайшего 1 января по времени Mac, сообщение 4 секунды и исчезновение. Санта сам не прилетает."
 },
 {
  "title": "Гирлянды и шапочки",
  "action": "Поставь гирлянду между несколькими креплениями, создай вторую и удали только одну. Проверь палитру, провисание и шапочки в «Ещё».",
  "expected": "Провод и лампочки связаны, свет мягкий, удаляется выбранная гирлянда. Обычные клики не блокируются. Для привязки к Dock может понадобиться Accessibility."
 },
 {
  "title": "Система, сохранение и сброс",
  "action": "Проверь Focus, уменьшение движения, Spaces, fullscreen и второй монитор при наличии. Перезапусти приложение; затем по желанию сбрось настройки.",
  "expected": "Focus без сюжетных сцен. Нет зависших зон ввода после fullscreen или отключения монитора. Настройки сохранены, сброс возвращает умеренный снег и чистые окна. Долгую работу и CPU проверь отдельно."
 }
];
window.SnowPlayChecks=tests;
let progress={current:0,results:{}},ready=false,busy=false;
const el=id=>document.getElementById(id),statusNames={passed:'Работает',failed:'Есть проблема',skipped:'Пропущен',pending:'Не проверен'};
function draw(){
 const i=progress.current,t=tests[i],record=progress.results[String(i+1)],completed=Object.values(progress.results).filter(r=>r.status!=='pending').length;
 el('test-progress').textContent=`${completed} из ${tests.length}`;el('test-meter').value=completed;
 el('test-index').textContent=`Тест ${i+1} из ${tests.length}`;el('test-title').textContent=t.title;el('test-action').textContent=t.action;el('test-expected').textContent=t.expected;el('test-note').value=record?.note||'';
 el('test-status').textContent=record?statusNames[record.status]:'Ещё не проверен';
 for(const id of ['test-pass','test-fail','test-skip','test-next','test-prev'])el(id).disabled=!ready||busy;
 el('test-prev').disabled=!ready||busy||i===0;el('test-next').disabled=!ready||busy||i===tests.length-1;
 el('test-note').disabled=!ready||busy;
 const list=el('test-all');list.replaceChildren();tests.forEach((test,index)=>{const li=document.createElement('li'),button=document.createElement('button');button.textContent=`${test.title} · ${statusNames[progress.results[String(index+1)]?.status]||'Не проверен'}`;button.classList.toggle('current',index===i);button.disabled=!ready||busy;button.addEventListener('click',()=>navigate(index));li.append(button);list.append(li);});
}
async function load(){
 try{progress=await request('/api/checks');ready=true;draw();}
 catch{el('test-save-status').textContent='Список откроется после подключения к SnowPlay.';setTimeout(load,2000);}
}
async function commit(next){
 if(!ready||busy)return false;const draft=next.results[String(progress.current+1)]?.note||'';let saved=false;busy=true;draw();
 try{if(!token){await refresh();if(!token)throw new Error('Нет подключения');}progress=await request('/api/checks',next);saved=true;el('test-save-status').textContent='Сохранено на этом Mac. При проблеме напиши мне номер теста и что произошло.';return true;}
 catch(e){el('test-save-status').textContent='Не удалось сохранить: '+e.message;return false;}
 finally{busy=false;draw();if(!saved)el('test-note').value=draft;}
}
function snapshot(){const copy=JSON.parse(JSON.stringify(progress)),id=String(progress.current+1),note=el('test-note').value;copy.results[id]={status:copy.results[id]?.status||'pending',note};return copy;}
async function mark(status){const next=snapshot();next.results[String(next.current+1)].status=status;if(status!=='failed')next.current=Math.min(tests.length-1,next.current+1);await commit(next);}
async function navigate(index){const next=snapshot();next.current=index;await commit(next);}
el('test-pass').addEventListener('click',e=>{if(e.detail<2)mark('passed');});el('test-fail').addEventListener('click',e=>{if(e.detail<2)mark('failed');});el('test-skip').addEventListener('click',e=>{if(e.detail<2)mark('skipped');});el('test-prev').addEventListener('click',()=>navigate(Math.max(0,progress.current-1)));el('test-next').addEventListener('click',()=>navigate(Math.min(tests.length-1,progress.current+1)));
el('test-export').addEventListener('click',()=>{const copy=snapshot(),lines=['SnowPlay — результаты ручной проверки',new Date().toLocaleString('ru-RU'),''];tests.forEach((t,i)=>{const r=copy.results[String(i+1)];lines.push(`${i+1}. ${t.title}: ${r?statusNames[r.status]:'Не проверен'}`);if(r?.note)lines.push('   '+r.note.replace(/\n/g,'\n   '));});const blob=new Blob([lines.join('\n')],{type:'text/plain;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='SnowPlay-проверка.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
draw();load();
})();
