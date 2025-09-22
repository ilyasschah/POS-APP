using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductGroupCommands.Add
{
    public class AddProductGroupCommand : IRequest<ProductGroupDto>
    {
        public CreateProductGroupRequest Request { get; }

        public AddProductGroupCommand(CreateProductGroupRequest request)
        {
            Request = request;
        }

        public class AddProductGroupCommandHandler : IRequestHandler<AddProductGroupCommand, ProductGroupDto>
        {
            private readonly ProductGroupService _service;

            public AddProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public async Task<ProductGroupDto> Handle(AddProductGroupCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperProductGroup.MapToProductGroupDto(entity);
            }
        }

        public class AddProductGroupCommandValidator : AbstractValidator<AddProductGroupCommand>
        {
            public AddProductGroupCommandValidator()
            {
                RuleFor(x => x.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(x => x.Request.Color).MaximumLength(50).When(x => x.Request.Color != null);
                RuleFor(x => x.Request.Rank).GreaterThanOrEqualTo(0).When(x => x.Request.Rank.HasValue);
                RuleFor(x => x.Request.ParentGroupId).GreaterThan(0).When(x => x.Request.ParentGroupId.HasValue);
            }
        }
    }
}
