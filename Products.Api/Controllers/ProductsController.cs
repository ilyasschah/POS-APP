using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.ProductsQuery.Get;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProductsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductDto>>> GetProducts()
        {
            return Ok(await mediator.Send(new GettAllProductsQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CreateProductRequest>> AddProduct([FromBody] CreateProductRequest createDto)
        {
            return Ok(await mediator.Send(new AddProductcommand(createDto)));
        }
        //[HttpPut("[action]")]
        //public async Task<ActionResult<CreateProductRequestDto>> UpdateProduct(int id, [FromBody] UpdateProductRequestDto updateDto)
        //{
        //    if (updateDto == null)
        //    {
        //        return BadRequest("Invalid product data.");
        //    }
        //    var command = new UpdateProductcommand(id, updateDto);
        //    var updatedProduct = await mediator.Send(command);
        //    return Ok(updatedProduct);
        //}
        //[HttpGet("{id}")]
        //[ProducesResponseType(typeof(ProductDto), StatusCodes.Status200OK)]
        //[ProducesResponseType(StatusCodes.Status404NotFound)]
        //public async Task<ActionResult<ProductDto>> GetById(int id)
        //{
        //    var product = await _mediator.Send(new GetProductByIdQuery(id));
        //    if (product == null)
        //    {
        //        return NotFound();
        //    }
        //    return Ok(product);
        //}
        //[HttpDelete("{id}")]
        //[ProducesResponseType(StatusCodes.Status204NoContent)]
        //[ProducesResponseType(StatusCodes.Status404NotFound)]
        //public async Task<IActionResult> DeleteProduct(int id)
        //{
        //    var command = new DeleteProductcommand(id);
        //    var result = await mediator.Send(command);
        //    if (result)
        //    {
        //        return NoContent();
        //    }
        //    return NotFound($"Product with ID {id} not found.");
        //}
    }
}