-- ============================================================================
-- UIInspector - Component Property Schema
-- Each component declares its own prop metadata as an ordered array.
-- Inspector walks the component hierarchy to collect all available props.
-- Properties belong to components; lookups walk Widget → component inheritance.
-- ============================================================================

local Schema = {}

-- Built by Schema.apply()
Schema._propOrder = nil    -- key → number (definition order for sorting)
Schema._tabProps = nil     -- tab → { key = true, ... }
Schema._labelMap = nil     -- key → label (first-seen label for getPropLabel without widget)
Schema._resolved = nil     -- className → { key → def } (预算的完整属性表，含继承)

Schema.COMPONENTS = {
    Widget = {
        propDefs = {
            -- common
            { key = "id",              label = "ID",         type = "string",  tab = { "common" } },
            { key = "visible",         label = "显示",       type = "boolean", tab = { "common" } },
            -- layout: size
            { key = "width",           label = "宽度",       type = "layout",  tab = { "common", "layout" } },
            { key = "height",          label = "高度",       type = "layout",  tab = { "common", "layout" } },
            { key = "minWidth",        label = "最小宽度",   type = "layout",  tab = { "layout" } },
            { key = "maxWidth",        label = "最大宽度",   type = "layout",  tab = { "layout" } },
            { key = "minHeight",       label = "最小高度",   type = "layout",  tab = { "layout" } },
            { key = "maxHeight",       label = "最大高度",   type = "layout",  tab = { "layout" } },
            { key = "flex",            label = "弹性值",     type = "number",  tab = { "layout" } },
            { key = "flexBasis",       label = "弹性基准尺寸", type = "layout", tab = { "layout" } },
            { key = "aspectRatio",     label = "宽高比",     type = "number",  tab = { "common", "layout" } },
            -- layout: position
            { key = "position",        label = "定位方式",   type = "enum",    tab = { "layout" }, options = {
                { value = "relative", label = "跟随布局（relative）" },
                { value = "absolute", label = "自由定位（absolute）" },
            } },
            { key = "left",            label = "左偏移",     type = "layout",  tab = { "layout" } },
            { key = "top",             label = "上偏移",     type = "layout",  tab = { "layout" } },
            { key = "right",           label = "右偏移",     type = "layout",  tab = { "layout" } },
            { key = "bottom",          label = "下偏移",     type = "layout",  tab = { "layout" } },
            -- layout: margin
            { key = "margin",          label = "外边距",     type = "spacing", tab = { "layout" } },
            { key = "marginTop",       label = "上外边距",   type = "layout",  tab = { "layout" } },
            { key = "marginRight",     label = "右外边距",   type = "layout",  tab = { "layout" } },
            { key = "marginBottom",    label = "下外边距",   type = "layout",  tab = { "layout" } },
            { key = "marginLeft",      label = "左外边距",   type = "layout",  tab = { "layout" } },
            { key = "marginHorizontal", label = "水平外边距", type = "layout",  tab = { "layout" } },
            { key = "marginVertical",   label = "垂直外边距", type = "layout",  tab = { "layout" } },
            -- layout: padding
            { key = "padding",         label = "内边距",     type = "spacing", tab = { "layout" } },
            { key = "paddingTop",      label = "上内边距",   type = "layout",  tab = { "layout" } },
            { key = "paddingRight",    label = "右内边距",   type = "layout",  tab = { "layout" } },
            { key = "paddingBottom",   label = "下内边距",   type = "layout",  tab = { "layout" } },
            { key = "paddingLeft",     label = "左内边距",   type = "layout",  tab = { "layout" } },
            { key = "paddingHorizontal", label = "水平内边距", type = "layout",  tab = { "layout" } },
            { key = "paddingVertical",   label = "垂直内边距", type = "layout",  tab = { "layout" } },
            -- layout: container (only shown for widgets with children)
            { key = "flexDirection",   label = "主轴方向",   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "row", label = "横向" },
                { value = "column", label = "纵向" },
                { value = "row-reverse", label = "横向反向" },
                { value = "column-reverse", label = "纵向反向" },
            } },
            { key = "justifyContent",  label = "主轴对齐",   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "flex-start", label = "起点" },
                { value = "center", label = "居中" },
                { value = "flex-end", label = "终点" },
                { value = "space-between", label = "两端分布" },
                { value = "space-around", label = "环绕分布" },
                { value = "space-evenly", label = "均匀分布" },
            } },
            { key = "alignItems",      label = "交叉轴对齐", type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "stretch", label = "拉伸" },
                { value = "flex-start", label = "起点" },
                { value = "center", label = "居中" },
                { value = "flex-end", label = "终点" },
                { value = "baseline", label = "基线" },
            } },
            { key = "alignSelf",       label = "自身对齐",   type = "enum",    tab = { "layout" }, options = {
                { value = "auto", label = "自动" },
                { value = "stretch", label = "拉伸" },
                { value = "flex-start", label = "起点" },
                { value = "center", label = "居中" },
                { value = "flex-end", label = "终点" },
                { value = "baseline", label = "基线" },
            } },
            { key = "alignContent",    label = "多行对齐",   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "stretch", label = "拉伸" },
                { value = "flex-start", label = "起点" },
                { value = "center", label = "居中" },
                { value = "flex-end", label = "终点" },
                { value = "space-between", label = "两端分布" },
                { value = "space-around", label = "环绕分布" },
            } },
            { key = "flexGrow",        label = "弹性增长比", type = "number",  tab = { "layout" } },
            { key = "flexShrink",      label = "弹性收缩比", type = "number",  tab = { "layout" } },
            { key = "flexWrap",        label = "弹性换行方式", type = "enum",   tab = { "layout" }, container = true, options = {
                { value = "nowrap", label = "不换行" },
                { value = "wrap", label = "换行" },
                { value = "wrap-reverse", label = "反向换行" },
            } },
            { key = "gap",             label = "间距",       type = "number",  tab = { "layout" }, container = true },
            { key = "rowGap",          label = "行间距",     type = "number",  tab = { "layout" }, container = true },
            { key = "columnGap",       label = "列间距",     type = "number",  tab = { "layout" }, container = true },
            -- appearance
            { key = "backgroundColor", label = "背景色",     type = "color",   tab = { "common", "appearance" } },
            { key = "backgroundImage", label = "背景图",     type = "path",    tab = { "appearance" } },
            { key = "backgroundFit",   label = "背景适配",   type = "enum",    tab = { "appearance" }, options = {
                { value = "cover", label = "覆盖" },
                { value = "contain", label = "包含" },
                { value = "fill", label = "填充" },
                { value = "none", label = "原始" },
            } },
            { key = "imageTint",       label = "图片着色",   type = "color",   tab = { "appearance" } },
            { key = "borderColor",     label = "边框颜色",   type = "color",   tab = { "common", "appearance" } },
            { key = "borderWidth",     label = "边框宽度",   type = "number",  tab = { "common", "appearance" } },
            { key = "borderRadius",    label = "圆角",       type = "number",  tab = { "common", "appearance" } },
            { key = "opacity",         label = "透明度",     type = "number",  tab = { "common", "appearance" } },
            { key = "zIndex",          label = "层级（zIndex）", type = "number", tab = { "appearance" } },
            -- interaction
            { key = "overflow",        label = "溢出",       type = "enum",    tab = { "interaction" }, options = {
                { value = "visible", label = "显示" },
                { value = "hidden", label = "隐藏" },
                { value = "scroll", label = "滚动" },
            } },
            { key = "pointerEvents",   label = "事件响应",   type = "enum",    tab = { "interaction" }, options = {
                { value = "auto", label = "自动" },
                { value = "none", label = "穿透" },
                { value = "box-none", label = "容器穿透" },
            } },
            { key = "cursor",          label = "鼠标指针（cursor）", type = "enum", tab = { "interaction" }, options = {
                { value = "default", label = "默认（default）" },
                { value = "pointer", label = "手型（pointer）" },
                { value = "move", label = "移动（move）" },
                { value = "text", label = "文本（text）" },
                { value = "grab", label = "可抓取（grab）" },
                { value = "grabbing", label = "抓取中（grabbing）" },
                { value = "not-allowed", label = "禁用（not-allowed）" },
            } },
            { key = "scale",           label = "缩放",       type = "number",  tab = { "interaction" } },
            { key = "rotate",          label = "旋转",       type = "number",  tab = { "interaction" } },
            { key = "translateX",      label = "水平偏移",   type = "number",  tab = { "interaction" } },
            { key = "translateY",      label = "垂直偏移",   type = "number",  tab = { "interaction" } },
        },
    },

    Panel = {},
    Card = {},
    SafeAreaView = {},
    ScrollView = {
        propDefs = {
            { key = "scrollX",             label = "水平滚动",   type = "boolean", tab = { "interaction" } },
            { key = "scrollY",             label = "垂直滚动",   type = "boolean", tab = { "interaction" } },
            { key = "showScrollbar",       label = "显示滚动条", type = "boolean", tab = { "interaction" } },
            { key = "scrollbarInteractive", label = "滚动条交互", type = "boolean", tab = { "interaction" } },
            { key = "allowOverflow",       label = "允许溢出",   type = "boolean", tab = { "interaction" } },
        },
    },

    Label = {
        propDefs = {
            { key = "text",            label = "文本",       type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = "占位文本",   type = "string",  tab = { "content" } },
            { key = "fontSize",        label = "字号",       type = "number",  tab = { "common", "content" } },
            { key = "fontFamily",      label = "字体",       type = "string",  tab = { "content" } },
            { key = "fontWeight",      label = "字体粗细",   type = "string",  tab = { "content" } },
            { key = "fontColor",       label = "字体颜色",   type = "color",   tab = { "common", "content" } },
            { key = "color",           label = "颜色",       type = "color",   tab = { "common", "content" } },
            { key = "lineHeight",      label = "行高",       type = "number",  tab = { "content" } },
            { key = "letterSpacing",   label = "字间距",     type = "number",  tab = { "content" } },
            { key = "textAlign",       label = "文本对齐",   type = "enum",    tab = { "content" }, options = {
                { value = "left", label = "左对齐" },
                { value = "center", label = "居中" },
                { value = "right", label = "右对齐" },
            } },
            { key = "verticalAlign",   label = "垂直对齐",   type = "enum",    tab = { "content" }, options = {
                { value = "top", label = "顶部" },
                { value = "middle", label = "居中" },
                { value = "bottom", label = "底部" },
            } },
            { key = "whiteSpace",      label = "换行方式",   type = "enum",    tab = { "content" }, options = {
                { value = "nowrap", label = "不换行" },
                { value = "normal", label = "自动换行" },
            } },
            { key = "textColor",       label = "文字颜色",   type = "color",   tab = { "common", "content" } },
            { key = "maxLines",        label = "最大行数",    type = "number",  tab = { "content" } },
            { key = "wordBreak",       label = "换行策略（wordBreak）", type = "enum", tab = { "content" }, options = {
                { value = "normal", label = "默认" },
                { value = "break-word", label = "断词换行" },
            } },
            { key = "textDecoration",  label = "文本装饰（textDecoration）", type = "enum", tab = { "content" }, options = {
                { value = "none", label = "无" },
                { value = "underline", label = "下划线" },
                { value = "line-through", label = "删除线" },
            } },
            { key = "textTransform",   label = "大小写转换（textTransform）", type = "enum", tab = { "content" }, options = {
                { value = "none", label = "无" },
                { value = "uppercase", label = "大写" },
                { value = "lowercase", label = "小写" },
                { value = "capitalize", label = "首字母大写" },
            } },
        },
    },
    RichText = {
        propDefs = {
            { key = "text", label = "文本", type = "string", tab = { "common", "content" } },
        },
    },
    Button = {
        propDefs = {
            { key = "text",            label = "文本",       type = "string",  tab = { "common", "content" } },
            { key = "fontSize",        label = "字号",       type = "number",  tab = { "common", "content" } },
            { key = "fontFamily",      label = "字体",       type = "string",  tab = { "content" } },
            { key = "fontWeight",      label = "字体粗细",   type = "string",  tab = { "content" } },
            { key = "textAlign",       label = "文本对齐",   type = "enum",    tab = { "content" }, options = {
                { value = "left", label = "左对齐" },
                { value = "center", label = "居中" },
                { value = "right", label = "右对齐" },
            } },
            { key = "verticalAlign",   label = "垂直对齐",   type = "enum",    tab = { "content" }, options = {
                { value = "top", label = "顶部" },
                { value = "middle", label = "居中" },
                { value = "bottom", label = "底部" },
            } },
            { key = "variant",         label = "样式变体（variant）", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" },
                { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" },
                { value = "success", label = "success" },
                { value = "outline", label = "outline" },
                { value = "ghost", label = "ghost" },
            } },
            { key = "size",            label = "尺寸",       type = "enum",    tab = { "common", "appearance" }, options = {
                { value = "xs", label = "xs" }, { value = "sm", label = "sm" },
                { value = "md", label = "md" }, { value = "lg", label = "lg" }, { value = "xl", label = "xl" },
            } },
            { key = "disabled",        label = "禁用",       type = "boolean", tab = { "common", "interaction" } },
            { key = "textColor",       label = "文字颜色",   type = "color",   tab = { "common", "content" } },
            { key = "icon",            label = "图标文本",   type = "path",    tab = { "content" } },
            { key = "iconSize",        label = "图标尺寸",   type = "number",  tab = { "content" } },
            { key = "hoverBackgroundColor",   label = "悬停背景色", type = "color", tab = { "interaction" } },
            { key = "pressedBackgroundColor", label = "按下背景色", type = "color", tab = { "interaction" } },
            { key = "disabledBackgroundColor", label = "禁用背景色", type = "color", tab = { "interaction" } },
            { key = "hoverBorderColor", label = "悬停边框色", type = "color", tab = { "interaction" } },
        },
    },
    TextField = {
        propDefs = {
            { key = "value",           label = "输入值",     type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = "占位文本",   type = "string",  tab = { "content" } },
            { key = "fontSize",        label = "字号",       type = "number",  tab = { "common", "content" } },
            { key = "disabled",        label = "禁用",       type = "boolean", tab = { "common", "interaction" } },
            { key = "readOnly",        label = "只读",       type = "boolean", tab = { "interaction" } },
            { key = "password",        label = "密码模式",   type = "boolean", tab = { "interaction" } },
            { key = "maxLength",       label = "最大长度",   type = "number",  tab = { "interaction" } },
            { key = "placeholderColor", label = "占位文字色", type = "color",  tab = { "interaction" } },
            { key = "selectionColor",  label = "选区颜色",   type = "color",  tab = { "interaction" } },
            { key = "cursorColor",     label = "光标颜色",   type = "color",  tab = { "interaction" } },
        },
    },
    Dropdown = {
        propDefs = {
            { key = "value",           label = "选中值",     type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = "占位文本",   type = "string",  tab = { "content" } },
            { key = "disabled",        label = "禁用",       type = "boolean", tab = { "common", "interaction" } },
            { key = "maxVisibleItems", label = "最多可见项", type = "number",  tab = { "interaction" } },
            { key = "itemHeight",      label = "选项高度",   type = "number",  tab = { "interaction" } },
            { key = "triggerBgColor",  label = "触发区背景色", type = "color", tab = { "interaction" } },
            { key = "arrowColor",      label = "箭头颜色",   type = "color",  tab = { "interaction" } },
            { key = "itemHoverBgColor", label = "悬停项背景色", type = "color", tab = { "interaction" } },
            { key = "itemHoverTextColor", label = "悬停项文字色", type = "color", tab = { "interaction" } },
            { key = "itemSelectedColor", label = "选中项背景色", type = "color", tab = { "interaction" } },
            { key = "itemSelectedTextColor", label = "选中项文字色", type = "color", tab = { "interaction" } },
            { key = "popupBorderColor", label = "弹出层边框色", type = "color", tab = { "interaction" } },
        },
    },

    Checkbox = {
        propDefs = {
            { key = "label",    label = "标签",     type = "string",  tab = { "common", "content" } },
            { key = "checked",  label = "选中",     type = "boolean", tab = { "common", "interaction" } },
            { key = "disabled", label = "禁用",     type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize", label = "字号",     type = "number",  tab = { "common", "content" } },
            { key = "fontColor", label = "字体颜色", type = "color",  tab = { "content" } },
        },
    },
    Toggle = {
        propDefs = {
            { key = "label",    label = "标签",     type = "string",  tab = { "common", "content" } },
            { key = "checked",  label = "选中",     type = "boolean", tab = { "common", "interaction" } },
            { key = "disabled", label = "禁用",     type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize", label = "字号",     type = "number",  tab = { "common", "content" } },
            { key = "fontColor", label = "字体颜色", type = "color",  tab = { "content" } },
        },
    },
    Slider = {
        propDefs = {
            { key = "value",    label = "数值",   type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = "最小值", type = "number",  tab = { "interaction" } },
            { key = "max",      label = "最大值", type = "number",  tab = { "interaction" } },
            { key = "step",     label = "步长",   type = "number",  tab = { "interaction" } },
            { key = "disabled", label = "禁用",   type = "boolean", tab = { "common", "interaction" } },
        },
    },
    Stepper = {
        propDefs = {
            { key = "value",    label = "数值",   type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = "最小值", type = "number",  tab = { "interaction" } },
            { key = "max",      label = "最大值", type = "number",  tab = { "interaction" } },
            { key = "step",     label = "步长",   type = "number",  tab = { "interaction" } },
            { key = "disabled", label = "禁用",   type = "boolean", tab = { "common", "interaction" } },
        },
    },
    ProgressBar = {
        propDefs = {
            { key = "value",    label = "值",     type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = "最小值", type = "number",  tab = { "interaction" } },
            { key = "max",      label = "最大值", type = "number",  tab = { "interaction" } },
            { key = "progress", label = "进度",   type = "number",  tab = { "interaction" } },
        },
    },
    Rating = {
        propDefs = {
            { key = "value",    label = "评分",   type = "number",  tab = { "common", "interaction" } },
            { key = "max",      label = "最大值", type = "number",  tab = { "interaction" } },
            { key = "disabled", label = "禁用",   type = "boolean", tab = { "common", "interaction" } },
        },
    },

    Alert = {
        propDefs = {
            { key = "title",   label = "标题", type = "string", tab = { "common", "content" } },
            { key = "message", label = "内容", type = "string", tab = { "common", "content" } },
            { key = "variant", label = "样式变体（variant）", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" }, { value = "success", label = "success" },
            } },
            { key = "icon",    label = "图标文本", type = "path", tab = { "content" } },
        },
    },
    Badge = {
        propDefs = {
            { key = "text",      label = "文本", type = "string", tab = { "common", "content" } },
            { key = "label",     label = "标签", type = "string", tab = { "common", "content" } },
            { key = "variant",   label = "样式变体（variant）", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" }, { value = "success", label = "success" },
            } },
            { key = "size",      label = "尺寸", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "xs", label = "xs" }, { value = "sm", label = "sm" },
                { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
            { key = "fontSize",  label = "字号", type = "number", tab = { "common", "content" } },
            { key = "fontColor", label = "字体颜色", type = "color", tab = { "content" } },
        },
    },
    Chip = {
        propDefs = {
            { key = "text",      label = "文本", type = "string", tab = { "common", "content" } },
            { key = "label",     label = "标签", type = "string", tab = { "common", "content" } },
            { key = "variant",   label = "样式变体（variant）", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "outline", label = "outline" },
            } },
            { key = "size",      label = "尺寸", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "sm", label = "sm" }, { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
            { key = "disabled",  label = "禁用", type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize",  label = "字号", type = "number", tab = { "common", "content" } },
            { key = "fontColor", label = "字体颜色", type = "color", tab = { "content" } },
        },
    },
    Toast = {
        propDefs = {
            { key = "title",   label = "标题", type = "string", tab = { "common", "content" } },
            { key = "message", label = "内容", type = "string", tab = { "common", "content" } },
            { key = "variant", label = "样式变体（variant）", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "info", label = "info" }, { value = "success", label = "success" },
                { value = "warning", label = "warning" }, { value = "error", label = "error" },
            } },
            { key = "icon",    label = "图标文本", type = "path", tab = { "content" } },
        },
    },
    Tooltip = {
        propDefs = {
            { key = "title",   label = "标题", type = "string", tab = { "common", "content" } },
            { key = "message", label = "内容", type = "string", tab = { "common", "content" } },
        },
    },
    Modal = {
        propDefs = {
            { key = "title",   label = "标题", type = "string", tab = { "common", "content" } },
            { key = "message", label = "内容", type = "string", tab = { "common", "content" } },
        },
    },
    Popover = {
        propDefs = {
            { key = "title",   label = "标题", type = "string", tab = { "common", "content" } },
            { key = "message", label = "内容", type = "string", tab = { "common", "content" } },
        },
    },
    Avatar = {
        propDefs = {
            { key = "icon", label = "图标文本", type = "path", tab = { "content" } },
            { key = "size", label = "尺寸", type = "enum", tab = { "common", "appearance" }, options = {
                { value = "sm", label = "sm" }, { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
        },
    },
    Pagination = {
        propDefs = {
            { key = "current",  label = "当前页", type = "number", tab = { "common", "interaction" } },
            { key = "total",    label = "总页数", type = "number", tab = { "common", "interaction" } },
            { key = "disabled", label = "禁用",   type = "boolean", tab = { "common", "interaction" } },
        },
    },
}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

local function isColorPropName(key)
    return type(key) == "string" and key:sub(-5):lower() == "color"
end

local function optionSignature(options)
    if not options then return "" end
    local parts = {}
    for _, option in ipairs(options) do
        parts[#parts + 1] = tostring(option.value)
    end
    return table.concat(parts, "|")
end

local function propDefSignature(def)
    if not def then return nil end
    return table.concat({
        tostring(def.type or "string"),
        tostring(def.editor or ""),
        optionSignature(def.options),
    }, "#")
end

local function valueMatchesDef(key, value, def)
    if value == nil or not def then return true end
    local valueType = type(value)
    local defType = def.type
    if defType == "layout" then
        return valueType == "number" or valueType == "string"
    elseif defType == "spacing" then
        return valueType == "number" or valueType == "string" or valueType == "table"
    elseif defType == "color" then
        return valueType == "table" or valueType == "string"
    elseif defType == "number" then
        return valueType == "number"
    elseif defType == "boolean" then
        return valueType == "boolean"
    elseif defType == "string" or defType == "path" or defType == "enum" then
        return valueType == "string"
    end
    return true
end

local function inferRuntimePropDef(key, value)
    local valueType = type(value)
    if valueType == "number" then
        return { label = key, type = "number", generic = true }
    elseif valueType == "boolean" then
        return { label = key, type = "boolean", generic = true }
    elseif valueType == "string" then
        return { label = key, type = isColorPropName(key) and "color" or "string", generic = true }
    elseif valueType == "table" and isColorPropName(key) and #value >= 3 then
        return { label = key, type = "color", generic = true }
    end
    return nil
end

-- ============================================================================
-- Public API
-- ============================================================================

function Schema.apply()
    Schema._propOrder = {}
    Schema._tabProps = {}
    Schema._labelMap = {}

    local orderCounter = 0

    -- Widget first (base props), then all other components sorted alphabetically
    local componentOrder = { "Widget" }
    local others = {}
    for name in pairs(Schema.COMPONENTS) do
        if name ~= "Widget" then
            others[#others + 1] = name
        end
    end
    table.sort(others)
    for _, name in ipairs(others) do
        componentOrder[#componentOrder + 1] = name
    end

    for _, componentName in ipairs(componentOrder) do
        local component = Schema.COMPONENTS[componentName]
        for _, entry in ipairs(component.propDefs or {}) do
            local key = entry.key
            if key then
                -- Assign ordering (first seen wins)
                if not Schema._propOrder[key] then
                    orderCounter = orderCounter + 1
                    Schema._propOrder[key] = orderCounter
                end

                -- Label map (first seen wins, for getPropLabel without widget)
                if not Schema._labelMap[key] and entry.label then
                    Schema._labelMap[key] = entry.label
                end

                -- Tab index
                for _, tab in ipairs(entry.tab or {}) do
                    Schema._tabProps[tab] = Schema._tabProps[tab] or {}
                    Schema._tabProps[tab][key] = true
                end
            end
        end
    end

    -- 预算每个组件的完整属性表（Widget 基础 + 组件自有，子覆盖父）
    Schema._resolved = {}
    local function buildEntryDef(entry)
        local def = {}
        for k, v in pairs(entry) do
            if k ~= "key" then def[k] = v end
        end
        return def
    end
    local widgetDefs = {}
    for _, entry in ipairs((Schema.COMPONENTS.Widget or {}).propDefs or {}) do
        if entry.key then
            widgetDefs[entry.key] = buildEntryDef(entry)
        end
    end
    Schema._resolved.Widget = widgetDefs
    for _, componentName in ipairs(others) do
        local merged = {}
        for k, v in pairs(widgetDefs) do merged[k] = v end
        for _, entry in ipairs((Schema.COMPONENTS[componentName] or {}).propDefs or {}) do
            if entry.key then
                merged[entry.key] = buildEntryDef(entry)
            end
        end
        Schema._resolved[componentName] = merged
    end
end

function Schema.getPropDef(key)
    local resolved = Schema._resolved and Schema._resolved.Widget
    return resolved and resolved[key] or nil
end

function Schema.getPropOrder(key)
    return Schema._propOrder and Schema._propOrder[key] or nil
end

function Schema.getPropLabel(key)
    if Schema._labelMap and Schema._labelMap[key] then
        return Schema._labelMap[key]
    end
    return key
end

function Schema.getWidgetPropDef(key, widget)
    local className = widget and widget._className or "Widget"
    local resolved = Schema._resolved and Schema._resolved[className]
    if not resolved then
        resolved = Schema._resolved and Schema._resolved.Widget
    end
    if resolved and resolved[key] then
        return resolved[key]
    end
    return widget and widget.props and inferRuntimePropDef(key, widget.props[key]) or nil
end

function Schema.getWidgetPropKeyMap(widget)
    local keys = {}
    local className = widget and widget._className or "Widget"
    local resolved = Schema._resolved and Schema._resolved[className]
    if not resolved then
        resolved = Schema._resolved and Schema._resolved.Widget
    end
    if not resolved then return keys end

    local hasChildren = widget and widget.children and #widget.children > 0
    for key, def in pairs(resolved) do
        if not def.container or hasChildren then
            keys[key] = true
        end
    end
    return keys
end

function Schema.getEditableProps(widgets, sortFn)
    if not widgets or #widgets == 0 then return {} end

    local result = Schema.getWidgetPropKeyMap(widgets[1])
    for i = 2, #widgets do
        local other = Schema.getWidgetPropKeyMap(widgets[i])
        for key in pairs(result) do
            if not other[key] then
                result[key] = nil
            end
        end
    end

    local keys = {}
    for key in pairs(result) do
        local _, conflict = Schema.getPropDefForWidgets(key, widgets)
        if not conflict then
            keys[#keys + 1] = key
        end
    end
    if sortFn then sortFn(keys) else table.sort(keys) end
    return keys
end

function Schema.getPropDefForWidgets(key, widgets)
    local chosen = nil
    local signature = nil
    for _, widget in ipairs(widgets or {}) do
        local def = Schema.getWidgetPropDef(key, widget)
        local value = widget and widget.props and widget.props[key] or nil
        if def then
            local currentSignature = propDefSignature(def)
            if signature and currentSignature ~= signature then
                return nil, true
            end
            signature = signature or currentSignature
            chosen = def
        elseif value ~= nil then
            return nil, true
        elseif chosen then
            return nil, true
        end

        if value ~= nil and def and not valueMatchesDef(key, value, def) then
            return nil, true
        end
    end

    return chosen, false
end

return Schema
