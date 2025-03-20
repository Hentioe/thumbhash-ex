export default {
const binaryToBase64 = binary => btoa(String.fromCharCode(...binary))
const base64ToBinary = base64 => new Uint8Array(atob(base64).split('').map(x => x.charCodeAt(0)))

    mounted() {
      let { data } = this.el.dataset;
      let thumbHashFromBase64 = base64ToBinary(data.thumbhash)
      let placeholderURL = ThumbHash.thumbHashToDataURL(thumbHashFromBase64)

      this.el.addEventListener("error", (ev) => {
        ev.preventDefault();
        ev.target.src = url(placeholderURL)
        ev.onerror = null
      });
    }
}