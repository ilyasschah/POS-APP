using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.CurrenciesCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.CurrenciesQuery.Get;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CurrenciesController(IMediator mediator) : ControllerBase
    {
        // GET: api/Currencys
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CurrencyDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllCurrenciesQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CurrencyDto>> AddCurrencycommand([FromBody] CreateCurrencyRequest createrequest)
        {
            return Ok(await mediator.Send(new AddCurrencycommand(createrequest)));
        }
        // GET: api/Currencys/id
        //[HttpGet("{id}")]
        //public async Task<IActionResult> GetCurrency(int id)
        //{
        //    var currency = await _db.Currencys
        //        .Where(cr => cr.Id == id)
        //        .Select(cr => new Currency
        //        {
        //            Id = cr.Id,
        //            Name = cr.Name,
        //            Code = cr.Code
        //        })
        //        .FirstOrDefaultAsync();
        //    if (currency == null)
        //    {
        //        return NotFound();
        //    }
        //    return Ok(currency);
        //}
        // POST: api/Currencys
        //[HttpPost]
        //public async Task<IActionResult> CreateCurrency([FromBody] Currency currency)
        //{
        //    if (currency == null || string.IsNullOrEmpty(currency.Name) || string.IsNullOrEmpty(currency.Code))
        //    {
        //        return BadRequest("Invalid currency data.");
        //    }
        //    _db.Currencys.Add(currency);
        //    await _db.SaveChangesAsync();
        //    return CreatedAtAction(nameof(GetCurrency), new { id = currency.Id }, currency);
        //}
        // PUT: api/Currencys/id
        //[HttpPut("{id}")]
        //public async Task<IActionResult> UpdateCurrency(int id, [FromBody] Currency currency)
        //{
        //    if (currency == null || id != currency.Id || string.IsNullOrEmpty(currency.Name) || string.IsNullOrEmpty(currency.Code))
        //    {
        //        return BadRequest("Invalid currency data.");
        //    }
        //    var existingCurrency = await _db.Currencys.FindAsync(id);
        //    if (existingCurrency == null)
        //    {
        //        return NotFound();
        //    }
        //    existingCurrency.Name = currency.Name;
        //    existingCurrency.Code = currency.Code;
        //    _db.Currencys.Update(existingCurrency);
        //    await _db.SaveChangesAsync();
        //    return Ok(existingCurrency);
        //}
        // DELETE: api/Currencys/id
        //[HttpDelete("{id}")]
        //public async Task<IActionResult> DeleteCurrency(int id)
        //{
        //    var currency = await _db.Currencys.FindAsync(id);
        //    if (currency == null)
        //    {
        //        return NotFound();
        //    }
        //    _db.Currencys.Remove(currency);
        //    await _db.SaveChangesAsync();
        //    return NoContent();
        //}
    }
}
