(() => {
  const margin = 5;
  const minHotelPrice = 5;
  const maxHotelPrice = 295;
  const passLimit = 50;

  function customerPriceForHotelPrice(value) {
    const hotelPrice = typeof value === 'string' && /^\d+$/.test(value.trim())
      ? Number(value) : value;
    if (!Number.isInteger(hotelPrice) || hotelPrice < minHotelPrice || hotelPrice > maxHotelPrice) {
      throw new RangeError(`Enter a whole number from ${minHotelPrice} to ${maxHotelPrice} for the hotel price.`);
    }
    return hotelPrice + margin;
  }

  function hotelPriceForCustomerPrice(price) {
    return Number.isSafeInteger(price) ? price - margin : '';
  }

  function isPassEligible(price) {
    return Number.isInteger(price) && price > 0 && price <= passLimit;
  }

  const pricing = { minHotelPrice, maxHotelPrice, customerPriceForHotelPrice, hotelPriceForCustomerPrice, isPassEligible };
  if (typeof window !== 'undefined') window.HungrPricing = pricing;
  if (typeof module !== 'undefined' && module.exports) module.exports = pricing;
})();
