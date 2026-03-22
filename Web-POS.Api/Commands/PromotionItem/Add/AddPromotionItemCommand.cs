using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Services;
using Api.Models;

namespace Api.Commands.PromotionItem.Add
{
    public class AddPromotionItemCommand : IRequest<PromotionItemDto>
    {
        public CreatePromotionItemRequest Request { get; }

        public AddPromotionItemCommand(CreatePromotionItemRequest request)
        {
            Request = request;
        }

        public class AddPromotionItemCommandHandler : IRequestHandler<AddPromotionItemCommand, PromotionItemDto>
        {
            private readonly PromotionItemService _service;

            public AddPromotionItemCommandHandler(PromotionItemService service)
            {
                _service = service;
            }

            public async Task<PromotionItemDto> Handle(AddPromotionItemCommand command, CancellationToken cancellationToken)
            {
                var newEntity = await _service.Create(command.Request);
                return MapperPromotionItem.MapToPromotionItemDto(newEntity);
            }
        }

        public class AddPromotionItemCommandValidator : AbstractValidator<AddPromotionItemCommand>
        {
            public AddPromotionItemCommandValidator()
            {
                RuleFor(c => c.Request.PromotionId).GreaterThan(0);
                RuleFor(c => c.Request.Uid).GreaterThan(0);
            }
        }
    }
}