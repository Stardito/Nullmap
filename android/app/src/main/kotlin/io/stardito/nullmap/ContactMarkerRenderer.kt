package io.stardito.nullmap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface
import kotlin.math.max
import kotlin.math.min

/** 地图上的一个联系人：坐标 + 头像字节（可为空，为空时画首字母）。 */
internal data class ContactPin(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val avatar: ByteArray?,
    /** 头像描边：由头像莫奈色 20% 融合中性色得到，未取到色时用中性色。 */
    val ringColor: Int = 0,
)

/**
 * 把联系人头像画成地图标记位图。
 *
 * - 单人：圆形头像 + 白色描边；
 * - 多人同区域：最多 3 个头像横向叠放，右上角角标显示总人数 `+N`。
 */
internal object ContactMarkerRenderer {
    private const val AVATAR_DP = 46f
    private const val AVATAR_RADIUS_DP = 23f
    private const val STACK_STEP_DP = 13f
    private const val BADGE_RADIUS_DP = 14f
    private const val MAX_STACK = 3

    private val COLORS = intArrayOf(
        Color.parseColor("#1565C0"),
        Color.parseColor("#2E7D32"),
        Color.parseColor("#EF6C00"),
        Color.parseColor("#6A1B9A"),
        Color.parseColor("#00838F"),
        Color.parseColor("#C62828"),
    )

    /** 单个联系人的圆形头像标记。 */
    fun single(context: Context, pin: ContactPin, fallbackRing: Int): Bitmap {
        val ringColor = if (pin.ringColor != 0) pin.ringColor else fallbackRing
        val density = context.resources.displayMetrics.density
        val radius = AVATAR_DP / 2f * density
        val ring = radius * 0.14f
        val size = ((radius + ring) * 2f).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawAvatar(canvas, size / 2f, size / 2f, radius, pin, ringColor)
        return bitmap
    }

    /** 区域内多个联系人的叠放标记，右上角标注总人数。 */
    fun cluster(context: Context, pins: List<ContactPin>, fallbackRing: Int): Bitmap {
        val ringColor = fallbackRing
        val density = context.resources.displayMetrics.density
        val radius = AVATAR_RADIUS_DP * density
        val step = STACK_STEP_DP * density
        val badgeRadius = BADGE_RADIUS_DP * density
        val shown = pins.take(MAX_STACK)
        val ring = radius * 0.14f
        val margin = 2f * density

        // 角标贴着最后一个头像的右上角；再按角标的实际外接框补齐画布，
        // 否则角标会被位图边缘裁掉（曾出现 +2 被切一半）。
        val lastCx = margin + ring + radius + step * (shown.size - 1)
        val badgeCx = lastCx + radius * 0.66f
        val badgeCy = margin + ring + radius * 0.34f
        val badgeLeft = badgeCx - badgeRadius
        val badgeTop = badgeCy - badgeRadius
        val shiftX = if (badgeLeft < 0f) -badgeLeft + margin else 0f
        val shiftY = if (badgeTop < 0f) -badgeTop + margin else 0f
        val top = margin + ring + shiftY
        // 角标也必须跟着平移：之前只平移了头像，角标仍画在原始坐标上，
        // 超出画布顶部的内容就被位图边缘切掉了（+N 顶部/左侧出现直边）。
        val finalBadgeCy = badgeCy + shiftY
        // 角标描边是 STROKE 画在半径上，会超出圆周半个线宽；
        // 画布再留一点余量，避免抗锯齿边缘被位图裁掉。
        val pad = badgeRadius * 0.12f
        val width = badgeCx + shiftX + badgeRadius + margin + pad
        val height = max(top + radius * 2f, finalBadgeCy + badgeRadius) + margin + pad
        val bitmap = Bitmap.createBitmap(
            width.toInt().coerceAtLeast(1),
            height.toInt().coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)

        // 从左往右画，后面的头像压住前面的，形成叠放。
        for (index in shown.indices.reversed()) {
            val cx = margin + ring + radius + step * index + shiftX
            val pin = shown[index]
            val avatarRing = if (pin.ringColor != 0) pin.ringColor else ringColor
            drawAvatar(canvas, cx, top + radius, radius, pin, avatarRing)
        }

        val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0D47A1")
        }
        val finalBadgeCx = badgeCx + shiftX
        canvas.drawCircle(finalBadgeCx, finalBadgeCy, badgeRadius, badgePaint)
        val badgeRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = badgeRadius * 0.16f
            color = ringColor
        }
        canvas.drawCircle(finalBadgeCx, finalBadgeCy, badgeRadius, badgeRing)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = badgeRadius * 0.95f
        }
        val label = "+${pins.size}"
        val maxTextWidth = badgeRadius * 1.5f
        val measured = textPaint.measureText(label)
        if (measured > maxTextWidth) {
            textPaint.textSize = textPaint.textSize * maxTextWidth / measured
        }
        val metrics = textPaint.fontMetrics
        canvas.drawText(
            label,
            finalBadgeCx,
            finalBadgeCy - (metrics.ascent + metrics.descent) / 2f,
            textPaint,
        )
        return bitmap
    }

    /**
     * 当前位置标记（Material 风格）：主色光晕 + 白色圆盘 + 主色实心点。
     *
     * 用来替换高德自带的蓝色定位点。
     */
    fun location(context: Context, primaryColor: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val halo = 22f * density
        val disc = 12f * density
        val size = (halo * 2f).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f

        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primaryColor
            alpha = 46
        }
        canvas.drawCircle(center, center, halo, haloPaint)

        val discPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.drawCircle(center, center, disc, discPaint)

        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = primaryColor }
        canvas.drawCircle(center, center, disc * 0.62f, dotPaint)
        return bitmap
    }

    /**
     * 目标点标记（Material 风格水滴图钉）：主色圆头 + 白色描边 + 白色中心点 + 尖尾。
     *
     * 用来替换高德默认的蓝色图钉，锚点设在尖尾（0.5, 1.0）。
     */
    fun pin(context: Context, color: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val radius = 17f * density
        val stroke = max(2.5f * density, 2f)
        val tail = 11f * density
        val width = (radius + stroke) * 2f
        val height = (radius + stroke) * 2f + tail
        val bitmap = Bitmap.createBitmap(
            width.toInt().coerceAtLeast(1),
            height.toInt().coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        )
        val canvas = Canvas(bitmap)
        val cx = width / 2f
        val cy = radius + stroke
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        // 尾部先画，圆头再盖上，接缝自然。
        val tailPath = Path().apply {
            moveTo(cx - radius * 0.62f, cy + radius * 0.55f)
            lineTo(cx + radius * 0.62f, cy + radius * 0.55f)
            lineTo(cx, height - stroke * 0.5f)
            close()
        }
        canvas.drawPath(tailPath, fill)
        canvas.drawCircle(cx, cy, radius, fill)

        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            this.color = Color.WHITE
        }
        canvas.drawCircle(cx, cy, radius - stroke / 2f, ring)
        val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = Color.WHITE }
        canvas.drawCircle(cx, cy, radius * 0.3f, dot)
        return bitmap
    }

    private fun drawAvatar(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        pin: ContactPin,
        ringColor: Int,
    ) {
        val bitmap = decode(pin.avatar)
        if (bitmap != null) {
            val shader = BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            val scale = (radius * 2f) / min(bitmap.width, bitmap.height).toFloat()
            val matrix = Matrix().apply {
                setScale(scale, scale)
                postTranslate(
                    cx - bitmap.width * scale / 2f,
                    cy - bitmap.height * scale / 2f,
                )
            }
            shader.setLocalMatrix(matrix)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.shader = shader }
            canvas.drawCircle(cx, cy, radius, paint)
        } else {
            val background = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = COLORS[(pin.name.hashCode() and 0x7FFFFFFF) % COLORS.size]
            }
            canvas.drawCircle(cx, cy, radius, background)
            drawInitial(canvas, cx, cy, radius, pin.name)
        }

        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(radius * 0.14f, 2f)
            color = ringColor
        }
        canvas.drawCircle(cx, cy, radius - ring.strokeWidth / 2f, ring)
    }

    private fun drawInitial(canvas: Canvas, cx: Float, cy: Float, radius: Float, name: String) {
        val initial = name.trim().take(1).uppercase()
        if (initial.isEmpty()) {
            return
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = radius * 0.95f
        }
        val metrics = paint.fontMetrics
        canvas.drawText(
            initial,
            cx,
            cy - (metrics.ascent + metrics.descent) / 2f,
            paint,
        )
    }

    private fun decode(bytes: ByteArray?): Bitmap? {
        if (bytes == null || bytes.isEmpty()) {
            return null
        }
        return runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }.getOrNull()
    }
}
