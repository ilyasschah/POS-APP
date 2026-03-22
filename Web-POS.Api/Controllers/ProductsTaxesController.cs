using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ProductTaxCommands.Add;
using Api.Commands.ProductTaxCommands.Delete;
using Api.Queries.ProductTaxQuery;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProductTaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllProductTaxesQuery()));
        }

        [HttpGet("[action]/ByProduct/{productId:int}")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetByProductId(int productId)
        {
            return Ok(await mediator.Send(new GetProductTaxesByProductIdQuery { ProductId = productId }));
        }

        [HttpGet("[action]/ByTax/{taxId:int}")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetByTaxId(int taxId)
        {
            return Ok(await mediator.Send(new GetProductTaxesByTaxIdQuery { TaxId = taxId }));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromQuery] CreateProductTaxRequest request)
        {
            return Ok(await mediator.Send(new AddProductTaxCommand { Request = request }));
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int productId, [FromQuery] int taxId)
        {
            return Ok(await mediator.Send(new DeleteProductTaxCommand { ProductId = productId, TaxId = taxId }));
        }
    }
}