package ua.rp.launcher

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.Charset

/** Відповідь сервера на SA:MP-запит 'i' (інформація). */
data class ServerInfo(
    val hostname: String,
    val gamemode: String,
    val language: String,
    val players: Int,
    val maxPlayers: Int,
    val hasPassword: Boolean,
    val pingMs: Long
)

/**
 * SA:MP Query Protocol — той самий, яким користується список серверів SA:MP.
 * open.mp його підтримує. Працює через UDP на порт сервера.
 */
object SampQuery {
    private val CP1251: Charset = Charset.forName("windows-1251")

    /** Блокуючий виклик — запускати тільки у фоновому потоці. */
    fun query(host: String, port: Int, timeoutMs: Int = 3000): ServerInfo? {
        return try {
            val address = InetAddress.getByName(host)
            val ip = address.address
            if (ip.size != 4) return null // сервер SA:MP працює лише по IPv4

            val req = ByteBuffer.allocate(11).order(ByteOrder.LITTLE_ENDIAN)
            req.put("SAMP".toByteArray(Charsets.US_ASCII))
            req.put(ip)
            req.putShort(port.toShort())
            req.put('i'.code.toByte())

            DatagramSocket().use { socket ->
                socket.soTimeout = timeoutMs
                val start = System.currentTimeMillis()
                socket.send(DatagramPacket(req.array(), 11, address, port))

                val buf = ByteArray(2048)
                val resp = DatagramPacket(buf, buf.size)
                socket.receive(resp)
                val ping = System.currentTimeMillis() - start

                val bb = ByteBuffer.wrap(buf, 0, resp.length).order(ByteOrder.LITTLE_ENDIAN)
                if (resp.length < 11 + 5 || bb.get(10) != 'i'.code.toByte()) return null
                bb.position(11)

                val password = bb.get().toInt() != 0
                val players = bb.short.toInt() and 0xFFFF
                val maxPlayers = bb.short.toInt() and 0xFFFF
                val hostname = readString(bb)
                val gamemode = readString(bb)
                val language = readString(bb)

                ServerInfo(hostname, gamemode, language, players, maxPlayers, password, ping)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun readString(bb: ByteBuffer): String {
        if (bb.remaining() < 4) return ""
        val len = bb.int
        if (len <= 0 || len > bb.remaining()) return ""
        val bytes = ByteArray(len)
        bb.get(bytes)
        return String(bytes, CP1251)
    }
}
