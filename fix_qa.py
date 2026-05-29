import os
path = os.path.join(os.path.dirname(__file__), 'scripts/components/explore_scene.gd')
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the questions array
old_marker = 'var questions := ['
new_content = '''\t# 16道题库，随机选4题
\tvar all_questions := [
\t\t{"q": "\\"%s\\"打量着你：\\"你是谁？为什么来这里？\\"" % owner_name,
\t\t "good": good_pool.slice(0, 2), "bad": bad_pool.slice(0, 2),
\t\t "good_fb": "\\"嗯...\\"——%s看起来稍微放松了一些。" % owner_name,
\t\t "bad_fb": "\\"嗯？\\"——%s皱起了眉头。" % owner_name},
\t\t{"q": "\\"%s\\"犹豫一下：\\"你有没有被丧尸咬过或抓伤?\\"" % owner_name,
\t\t "good": ["绝对没有", "身上没有伤口", "每天都检查，放心", "要是有伤我早死了"],
\t\t "bad": ["可能没有吧...不确定", "就算有又怎样?", "这点小伤不碍事", "我不记得了..."],
\t\t "good_fb": "\\"嗯...\\"——%s点了点头。" % owner_name,
\t\t "bad_fb": "\\"嗯？\\"——%s后退了半步，警惕地盯着你。" % owner_name},
\t\t{"q": "\\"%s\\"盯着你：\\"你愿意分享食物和水吗?\\"" % owner_name,
\t\t "good": ["愿意，互相帮助才能活下去", "我有罐头可以分享", "当然，大家一起熬过去", "有余粮，不会白吃白住"],
\t\t "bad": ["不行，那是我辛苦找到的", "凭什么?先进去再说", "我自己都不够吃", "看情况吧..."],
\t\t "good_fb": "\\"好...\\"——%s语气缓和了下来。" % owner_name,
\t\t "bad_fb": "\\"哼。\\"——%s冷笑了一声。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你一个人吗?还有别人跟你一起吗?\\"" % owner_name,
\t\t "good": ["就我一个", "同伴在附近等我", "之前是一个人走的", "队伍走散了，只剩我"],
\t\t "bad": ["这不用你管", "人多着呢，怕不怕?", "不告诉你", "你猜?"],
\t\t "good_fb": "%s若有所思地点了点头。" % owner_name,
\t\t "bad_fb": "%s眯起了眼睛，显得有些怀疑。" % owner_name},
\t\t{"q": "\\"%s\\"打量你的衣着：\\"你在外面待了多久了?\\"" % owner_name,
\t\t "good": ["好几天了", "大概三四天吧", "从爆发开始就一直在外漂", "记不清日子了，很久了"],
\t\t "bad": ["关你什么事?", "刚出来的，怎么样?", "一直在跟踪我?", "无可奉告"],
\t\t "good_fb": "\\"不容易啊...\\"%s叹了口气。" % owner_name,
\t\t "bad_fb": "%s的表情变得有些冷淡。" % owner_name},
\t\t{"q": "\\"%s\\"突然问：\\"你会打架吗?遇到丧尸怎么办?\\"" % owner_name,
\t\t "good": ["会一点，能自保", "尽量避开它们", "跑得快就行了", "有武器，能应付"],
\t\t "bad": ["我不会打架，你得保护我", "我直接跟它们拼了", "丧尸有什么好怕的", "我从没见过丧尸"],
\t\t "good_fb": "%s微微点头，似乎放心了一些。" % owner_name,
\t\t "bad_fb": "%s用奇怪的眼神看了你一眼。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你来之前是做什么的?\\"" % owner_name,
\t\t "good": ["普通工人", "做点小生意", "在超市上班", "以前当过保安"],
\t\t "bad": ["我什么都没做过", "以前混街头的", "这重要吗?", "你查户口呢?"],
\t\t "good_fb": "\\"原来如此...\\"%s若有所思。" % owner_name,
\t\t "bad_fb": "%s没有接话，眼神闪烁了一下。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"如果屋子里有人生病了，你会怎么办?\\"" % owner_name,
\t\t "good": ["尽力帮忙照顾", "找药给他们吃", "隔离起来免得传染", "大家一起想办法"],
\t\t "bad": ["直接赶出去算了", "跟我没关系", "先把自己顾好再说", "生病了就等死呗"],
\t\t "good_fb": "%s的眼神温和了下来。" % owner_name,
\t\t "bad_fb": "%s皱起眉，不太赞同地看着你。" % owner_name},
\t\t{"q": "\\"%s\\"沉声问：\\"你有没有杀过人?或者...杀过那些东西?\\"" % owner_name,
\t\t "good": ["不得已的时候会动手", "只杀丧尸，不伤人活人", "为了生存什么都得干", "杀过...不想回忆了"],
\t\t "bad": ["哈哈，我可是杀手", "杀过几个，很爽", "没杀过，我是和平主义者", "你这是在套我的话?"],
\t\t "good_fb": "%s沉默了一会儿，轻轻点了点头。" % owner_name,
\t\t "bad_fb": "%s后退一步，手放在了门把手上。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你觉得我们这里应该怎么防守?\\"" % owner_name,
\t\t "good": ["加固门窗最重要", "轮流值班站岗", "储备足够的物资", "保持安静别引丧尸过来"],
\t\t "bad": ["主动出击消灭它们", "防守没用，跑吧", "让其他人去守就行", "随便怎样都行"],
\t\t "good_fb": "\\"你说得有道理。\\"%s表示认同。" % owner_name,
\t\t "bad_fb": "%s摇了摇头，显然不同意你的看法。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你最怕什么?\\"" % owner_name,
\t\t "good": ["怕连累别人", "怕自己变成那种怪物", "怕再也见不到家人", "怕失去希望"],
\t\t "bad": ["我什么都不怕", "怕你废话太多", "最怕饿肚子", "怕被你这种人坑"],
\t\t "good_fb": "%s看着你的眼睛，似乎看到了真诚。" % owner_name,
\t\t "bad_fb": "%s嘴角抽动了一下，没说什么。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"如果有人想抢这屋子，你站在哪边?\\"" % owner_name,
\t\t "good": ["当然站你这边", "一起保护这个地方", "我会帮忙抵抗入侵者", "既然住了进来就是一家人"],
\t\t "bad": ["谁赢帮谁", "看给多少钱吧", "我不管闲事", "先保全自己再说"],
\t\t "good_fb": "%s露出了一丝安心的表情。" % owner_name,
\t\t "bad_fb": "%s的脸色阴沉了下来。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你对其他幸存者怎么看?\\"" % owner_name,
\t\t "good": ["大部分人都是好人", "不能一概而论", "谨慎接触但愿意相信人", "遇事看人品"],
\t\t "bad": ["都不能信只有自己靠谱", "利用完就扔", "管他死活与我何干", "幸存者比丧尸还可怕"],
\t\t "good_fb": "%s微微一笑，似乎对你有了好感。" % owner_name,
\t\t "bad_fb": "%s沉默不语，表情变得严肃。" % owner_name},
\t\t{"q": "\\"%s\\"问：\\"你有什么特长或技能吗?\\"" % owner_name,
\t\t "good": ["会修东西", "懂点急救知识", "力气活都能干", "擅长找物资"],
\t\t "bad": ["没什么特长", "我擅长睡觉", "你会需要我的...走着瞧", "技能?那是啥?"],
\t\t "good_fb": "\\"那太好了，我们正缺人手。\\"%s眼睛一亮。" % owner_name,
\t\t "bad_fb": "%s叹了口气，似乎有些失望。" % owner_name},
\t\t{"q": "\\"%s\\"突然问道：\\"你相信救援队还会来吗?\\"" % owner_name,
\t\t "good": ["总得抱有希望吧", "与其等救援不如自救", "信不信都得活下去", "也许有一天会来的"],
\t\t "bad": ["救援?早死心了", "根本没人会来救我们", "你居然还信这个?", "来了也没用"],
\t\t "good_fb": "%s点了点头：「说得对，活着才有希望。」" % owner_name,
\t\t "bad_fb": "%s沉默了，气氛变得有些尴尬。" % owner_name},
\t\t{"q": "\\"%s\\"最后问：\\"你晚上打呼噜吗?\\"" % owner_name,
\t\t "good": ["应该不会吧...", "不确定可以问问同住的人", "睡着了就不清楚了", "你要是不嫌弃的话"],
\t\t "bad": ["震天响，怕了吧?", "我打不打关你什么事", "你怎么问题这么奇怪", "你管得太宽了"],
\t\t "good_fb": "%s难得地笑了笑：\\"那就好，我怕吵。\\"" % owner_name,
\t\t "bad_fb": "%s面无表情地盯着你。" % owner_name},
\t]
\tall_questions.shuffle()
\tvar questions := all_questions.slice(0, 4)  # 随机选4题'''

idx = content.find(old_marker)
if idx >= 0:
    # Find the end: from old_marker to after questions.shuffle() + blank line
    end_marker = '\tquestions.shuffle()\n'
    end_idx = content.find(end_marker, idx)
    if end_idx >= 0:
        end_idx += len(end_marker)  # include the shuffle line
        # Also skip trailing newline
        while end_idx < len(content) and content[end_idx] in '\n\r':
            end_idx += 1
        content = content[:idx] + new_content + content[end_idx:]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('SUCCESS: QA question bank replaced')
    else:
        print('ERROR: end marker not found')
else:
    print('ERROR: start marker not found')
